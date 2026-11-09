$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
. (Join-Path $Root 'app/Core.ps1')
function Assert-True { param ([bool]$Condition, [string]$Message) if (-not $Condition) { throw $Message } }
function Assert-Throws {
    param ([scriptblock]$Action)
    $Thrown = $false
    try { & $Action | Out-Null } catch { $Thrown = $true }
    Assert-True $Thrown 'Beklenen hata oluşmadı.'
}
function Assert-Volume { param ([float]$Expected) Assert-True ([Math]::Abs($script:Volume - $Expected) -lt 0.001) "Ses yanlış: $script:Volume / $Expected" }
$RunDirectory = Join-Path $PSScriptRoot ('.runtime/core-' + [guid]::NewGuid())
[IO.Directory]::CreateDirectory($RunDirectory) | Out-Null
$CsvPath = Join-Path $RunDirectory 'fixture.csv'
$Header = 'il,ilce,tarih,imsak,gunes,ogle,ikindi,aksam,yatsi'
$First = 'İSTANBUL,KÜÇÜKÇEKMECE,2026-11-09,06:10,07:37,12:53,15:34,17:59,19:21'
$Second = 'İSTANBUL,KÜÇÜKÇEKMECE,2026-11-10,06:11,07:38,12:54,15:35,17:58,19:20'
@($Header, $First, $Second) | Set-Content -LiteralPath $CsvPath -Encoding UTF8
$Today = @(Get-DiyanetSchedule -Date ([datetime]'2026-11-09') -Sehir Istanbul -Ilce Kucukcekmece -CsvPath $CsvPath)
$Tomorrow = @(Get-DiyanetSchedule -Date ([datetime]'2026-11-10') -Sehir Istanbul -Ilce Kucukcekmece -CsvPath $CsvPath)
Assert-True ($Today.Count -eq 5 -and $Today[0].Vakit -eq 'imsak') 'Beş vakit ve imsak bekleniyor.'
Assert-True ($Tomorrow[0].Saat -eq '06:11') 'Günlük yenileme yanlış.'
Assert-True ((ConvertTo-LocationKey 'Iğdır') -eq 'IGDIR') 'Türkçe konum normalizasyonu yanlış.'
Assert-Throws { Get-DiyanetSchedule -Date ([datetime]'2027-01-01') -Ilce Kucukcekmece -CsvPath $CsvPath }
Assert-Throws { Get-DiyanetSchedule -Date ([datetime]'2026-11-09') -Ilce Yok -CsvPath $CsvPath }
@($Header, $First, $First) | Set-Content -LiteralPath $CsvPath -Encoding UTF8
Assert-Throws { Get-DiyanetSchedule -Date ([datetime]'2026-11-09') -Ilce Kucukcekmece -CsvPath $CsvPath }
@($Header, $First.Replace('06:10', '25:10')) | Set-Content -LiteralPath $CsvPath -Encoding UTF8
Assert-Throws { Get-DiyanetSchedule -Date ([datetime]'2026-11-09') -Ilce Kucukcekmece -CsvPath $CsvPath }
@('bad,header', $First) | Set-Content -LiteralPath $CsvPath -Encoding UTF8
Assert-Throws { [EzanCsv]::Inspect($CsvPath) }

# Gerçek ses cihazına dokunulmaz. Zamanı enjekte ederek bütün ezan döngüsü sınanır.
$script:Volume = 0.8; $script:FailWrite = $false; $script:OpenCount = 0; $script:CloseCount = 0
function Open-EzanAudio { $script:OpenCount++; return $script:Volume }
function Write-EzanVolume {
    param ([float]$Volume)
    if ($script:FailWrite) { $script:FailWrite = $false; throw 'Test ses hatası' }
    $script:Volume = $Volume
}
function Close-EzanAudio { $script:CloseCount++ }
$Start = [datetime]'2026-11-09T06:09:00'
function New-TestState {
    $State = New-EzanState
    $State.Running = $true; $State.Schedule = $Today; $State.ScheduleDate = $Start.Date
    return $State
}
$NoticeState = New-TestState
Assert-True ($null -eq (Get-EzanUpcomingAction $NoticeState $Start.AddSeconds(-16))) 'Uyarı erken gösterildi.'
$Upcoming = Get-EzanUpcomingAction $NoticeState $Start.AddSeconds(-15)
Assert-True ($Upcoming.Seconds -eq 15 -and -not $Upcoming.IsTest) '15 saniyelik uyarı oluşmadı.'
Assert-True ((Get-EzanUpcomingAction $NoticeState $Start.AddMilliseconds(-500)).Seconds -eq 1) 'Son saniye yanlış.'
Assert-True (-not (Skip-EzanUpcomingAction $NoticeState 'eski-uyarı' $Start.AddSeconds(-10))) 'Eski uyarı iptal edildi.'
Assert-True (Skip-EzanUpcomingAction $NoticeState $Upcoming.Key $Start.AddSeconds(-10)) 'Vakit atlanamadı.'
Assert-True ($NoticeState.Running -and $null -eq (Get-EzanUpcomingAction $NoticeState $Start.AddSeconds(-5))) 'İptal takibi durdurdu veya uyarı tekrarlandı.'
$Count = $script:OpenCount
Update-EzanTracking $NoticeState $Start
Update-EzanTracking $NoticeState $Start.AddSeconds(60)
Assert-True ($script:OpenCount -eq $Count) 'İptal edilen vakitte ses değişti.'
$NextAt = $Today[1].Tarih.AddMinutes(-1)
Assert-True ($null -ne (Get-EzanUpcomingAction $NoticeState $NextAt.AddSeconds(-15))) 'Sonraki vakit atlandı.'
Update-EzanTracking $NoticeState $NextAt
Assert-True ($script:OpenCount -eq ($Count + 1)) 'Sonraki vakit çalışmadı.'
Stop-EzanTracking $NoticeState
$NoticeState = New-EzanState
$NoticeState.TestAt = $Start
$Upcoming = Get-EzanUpcomingAction $NoticeState $Start.AddSeconds(-15)
Assert-True ($Upcoming.IsTest -and (Skip-EzanUpcomingAction $NoticeState $Upcoming.Key $Start.AddSeconds(-1))) 'Test uyarısı iptal edilemedi.'
Assert-True ($null -eq $NoticeState.TestAt -and -not $NoticeState.Running) 'Test iptali takip tercihini değiştirdi.'
Assert-True ($null -eq (Get-EzanUpcomingAction (New-TestState) $Start)) 'Başladıktan sonra uyarı gösterildi.'
$State = New-TestState
$Count = $script:OpenCount
Update-EzanTracking $State $Start.AddSeconds(-1)
Assert-True ($script:OpenCount -eq $Count) 'Vakitten bir dakikadan erken başladı.'
Update-EzanTracking $State $Start
Assert-True ($State.LastTriggered -eq '2026-11-09T06:10:00') 'Vakit kimliği değişti.'
Assert-Volume 0.8
Update-EzanTracking $State $Start.AddSeconds(30)
Assert-Volume 0.4
Update-EzanTracking $State $Start.AddSeconds(60)
Assert-Volume 0
Update-EzanTracking $State $Start.AddSeconds(539)
Assert-Volume 0
Update-EzanTracking $State $Start.AddSeconds(540)
Assert-True ($State.Phase -eq 'fade-in') 'Geri açılma ezan bitince başlamalı.'
Assert-Volume 0
Update-EzanTracking $State $Start.AddSeconds(555)
Assert-Volume 0.4
Update-EzanTracking $State $Start.AddSeconds(570)
Assert-Volume 0.8
Assert-True ($null -eq $State.OriginalVolume -and $State.Phase -eq 'waiting') '30 saniyede geri açılma tamamlanmadı.'

$State = New-TestState
Update-EzanTracking $State $Start
Update-EzanTracking $State $Start.AddSeconds(65)
Stop-EzanTracking $State
Assert-Volume 0.8
Assert-True (-not $State.Running) 'Takip durmadı.'
$State.Running = $true
$Count = $script:OpenCount
Update-EzanTracking $State $Start.AddSeconds(20)
Assert-True ($Count -eq $script:OpenCount) 'Aynı vakit iki kez tetiklendi.'

$State = New-TestState
Update-EzanTracking $State $Start
Update-EzanTracking $State $Start.AddSeconds(1000)
Assert-Volume 0.8
Assert-True ($null -eq $State.OriginalVolume) 'Uyku sonrası eski ses geri gelmedi.'

$State = New-TestState
Update-EzanTracking $State $Start
$script:FailWrite = $true
Update-EzanTracking $State $Start.AddSeconds(20)
Assert-Volume 0.8
Assert-True (-not $State.Running -and $State.Phase -eq 'error') 'Ses hatası güvenli biçimde ele alınmadı.'

$State = New-TestState
$State.FadeOutSeconds = 0
Update-EzanTracking $State $Start
Assert-Volume 0
Stop-EzanTracking $State
Assert-Volume 0.8
$State = New-TestState
$script:Volume = 0
Update-EzanTracking $State $Start
Update-EzanTracking $State $Start.AddSeconds(570)
Assert-Volume 0
Assert-True ($null -eq $State.OriginalVolume) 'Sıfır başlangıç sesi yönetilemedi.'

# Elle saat testi normal takip kapalıyken de tek sefer çalışır.
$script:Volume = 0.8
$State = New-EzanState
$Reference = [datetime]'2026-11-09T12:00:00'
Set-EzanTest -State $State -Time '12:01:02' -MuteSeconds 10 -FadeOutSeconds 2 -Now $Reference
$TestStart = $State.TestAt
Assert-True ($TestStart -eq [datetime]'2026-11-09T12:01:02' -and -not $State.Running) 'Elle test zamanı veya takip tercihi yanlış.'
$Count = $script:OpenCount
Update-EzanTracking $State $TestStart.AddSeconds(-1)
Assert-True ($script:OpenCount -eq $Count) 'Test erken tetiklendi.'
Update-EzanTracking $State $TestStart
Assert-True ($State.TestActive -and $null -eq $State.TestAt) 'Test başlamadı veya tek seferlik plan temizlenmedi.'
Assert-Throws { Set-EzanTest -State $State -Time '13:00' -Now $Reference }
Update-EzanTracking $State $TestStart.AddSeconds(1)
Assert-Volume 0.4
Update-EzanTracking $State $TestStart.AddSeconds(2)
Assert-Volume 0
Update-EzanTracking $State $TestStart.AddSeconds(10)
Assert-True ($State.Phase -eq 'fade-in') 'Testte geri açılma zamanı yanlış.'
Update-EzanTracking $State $TestStart.AddSeconds(25)
Assert-Volume 0.4
Update-EzanTracking $State $TestStart.AddSeconds(40)
Assert-Volume 0.8
Assert-True (-not $State.TestActive -and -not $State.Running -and $State.LastTriggered -eq '') 'Test normal takip tercihini veya son vakti değiştirdi.'
$Count = $script:OpenCount
Update-EzanTracking $State $TestStart.AddSeconds(41)
Assert-True ($script:OpenCount -eq $Count) 'Test ikinci kez tetiklendi.'

$State = New-TestState
Set-EzanTest -State $State -Time '12:01:02' -MuteSeconds 10 -FadeOutSeconds 2 -Now $Reference
Update-EzanTracking $State $State.TestAt
Update-EzanTracking $State $TestStart.AddSeconds(3)
Assert-Volume 0
Cancel-EzanTest $State
Assert-Volume 0.8
Assert-True ($State.Running -and -not $State.TestActive -and $null -eq $State.TestAt) 'İptal normal takibi değiştirdi.'
Assert-True ($State.MuteSeconds -eq 480 -and $State.FadeOutSeconds -eq 60) 'Test normal süreleri değiştirdi.'
Set-EzanTest -State $State -Time '11:59' -Now $Reference
Assert-True ($State.TestAt -eq [datetime]'2026-11-10T11:59:00') 'Geçmiş saat yarına planlanmadı.'
Stop-EzanTracking $State
Assert-True ($null -eq $State.TestAt) 'Durdurma bekleyen testi iptal etmedi.'
Assert-Throws { Set-EzanTest -State $State -Time '24:00' -Now $Reference }
Assert-Throws { Set-EzanTest -State $State -Time '12:00:99' -Now $Reference }
Assert-Throws { Set-EzanTest -State $State -Time '13:00' -MuteSeconds 1 -FadeOutSeconds 2 -Now $Reference }
Set-EzanTest -State $State -Time '12:01' -Now $Reference
$Count = $script:OpenCount
Update-EzanTracking $State ([datetime]'2026-11-09T12:03:00')
Assert-True ($script:OpenCount -eq $Count -and $null -eq $State.TestAt) 'Kaçırılan test sonradan çalıştırıldı.'

$ProgressState = New-EzanState
$ProgressState.PrayerStart = $Reference
$ProgressState.OriginalVolume = 0.8
$Progress = Get-EzanProgress $ProgressState $Reference.AddSeconds(30)
Assert-True ($Progress.Step -eq 1 -and $Progress.RemainingSeconds -eq 30 -and $Progress.TotalRemainingSeconds -eq 540) 'Kısılma geri sayımı yanlış.'
$Progress = Get-EzanProgress $ProgressState $Reference.AddSeconds(60)
Assert-True ($Progress.Step -eq 2 -and $Progress.RemainingSeconds -eq 480 -and $Progress.TotalRemainingSeconds -eq 510) 'Bekleme aşaması sınırı yanlış.'
$Progress = Get-EzanProgress $ProgressState $Reference.AddSeconds(555)
Assert-True ($Progress.Step -eq 3 -and $Progress.RemainingSeconds -eq 15 -and $Progress.TotalRemainingSeconds -eq 15 -and $Progress.Percent -eq 97) 'Geri açılma geri sayımı yanlış.'
$ProgressState.TestActive = $true
$ProgressState.TestMuteSeconds = 10; $ProgressState.TestFadeOutSeconds = 2
$Progress = Get-EzanProgress $ProgressState $Reference.AddSeconds(3)
Assert-True ($Progress.Step -eq 2 -and $Progress.RemainingSeconds -eq 7 -and $Progress.TotalRemainingSeconds -eq 37) 'Gösterge test sürelerini kullanmadı.'
$Progress = Get-EzanProgress $ProgressState $Reference.AddSeconds(39.1)
Assert-True ($Progress.RemainingSeconds -eq 1) 'Saniye geri sayımı erken sıfırlandı.'
$Progress = Get-EzanProgress $ProgressState $Reference.AddSeconds(100)
Assert-True ($Progress.Percent -eq 100 -and $Progress.TotalRemainingSeconds -eq 0) 'Gösterge süre/yüzde sınırlarını aştı.'
$ProgressState.OriginalVolume = $null
Assert-True ($null -eq (Get-EzanProgress $ProgressState $Reference)) 'Boştayken ilerleme gösteriliyor.'
Assert-True ((Format-EzanCountdown 3600) -eq '60:00' -and (Format-EzanCountdown 5) -eq '00:05') 'Süre biçimi yanlış.'

$SettingsDirectory = Join-Path $RunDirectory 'settings'
$Settings = Read-EzanSettings $SettingsDirectory
Assert-True ($Settings.City -eq 'İSTANBUL') 'Varsayılan ayarlar yanlış.'
Save-EzanSettings $Settings $SettingsDirectory
$Settings.Tracking = $false
Save-EzanSettings $Settings $SettingsDirectory
$Saved = Read-EzanSettings $SettingsDirectory
Assert-True (-not $Saved.Tracking) 'Ayarlar kalıcı değil.'
Assert-True (Test-Path (Join-Path $SettingsDirectory 'settings.backup.json')) 'Ayar yedeği yok.'

# Başlangıç kaydını gerçek Windows Startup klasörü yerine test klasöründe sınar.
$script:TestStartup = Join-Path $RunDirectory 'startup.lnk'
function Get-EzanStartupPath { $script:TestStartup }
Set-EzanStartup $true
Assert-True (Test-Path -LiteralPath $script:TestStartup) 'Başlangıç kısayolu oluşturulmadı.'
$Shell = New-Object -ComObject WScript.Shell
$Shortcut = $Shell.CreateShortcut($script:TestStartup)
Assert-True ($Shortcut.Arguments.Contains('-Background') -and $Shortcut.Arguments.Contains('insat.ps1')) 'Başlangıç komutu yanlış.'
Assert-True ($Shortcut.IconLocation -eq ((Join-Path $Root 'assets/insat.ico') + ',0')) 'Başlangıç kısayolu Insat ikonunu kullanmıyor.'
[Runtime.InteropServices.Marshal]::ReleaseComObject($Shortcut) | Out-Null
[Runtime.InteropServices.Marshal]::ReleaseComObject($Shell) | Out-Null
Set-EzanStartup $false
Assert-True (-not (Test-Path -LiteralPath $script:TestStartup)) 'Başlangıç kısayolu kaldırılmadı.'

$RealCsv = Join-Path $Root 'data/diyanet_namaz_vakitleri_turkiye.csv'
$Info = [EzanCsv]::Inspect($RealCsv)
Assert-True ($Info.FirstDate -eq '2026-01-01' -and $Info.LastDate -eq '2026-12-31') 'Veri kapsamı yanlış.'
Assert-True (@($Info.Locations | ForEach-Object { $_.Split('|')[0] } | Select-Object -Unique).Count -eq 81) '81 il bekleniyor.'
Assert-True ($Info.RowCount -eq ($Info.Locations.Count * 365)) 'Yıllık konum/gün sayısı tutarsız.'
Assert-True (@(Get-DiyanetSchedule -Date ([datetime]'2026-11-09') -Ilce Kucukcekmece -CsvPath $RealCsv).Count -eq 5) 'Gerçek CSV okunamadı.'
Add-Type -Path (Join-Path $Root 'app/Audio.cs')
Write-Host 'Başarılı: CSV, konum/tarih, hata durumları, 30 saniyelik dönüş, durdurma, uyku, tek tetikleme, kalıcı ayarlar, başlangıç kısayolu ve ses API derlemesi.'

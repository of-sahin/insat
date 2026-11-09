$script:ProductRoot = Split-Path $PSScriptRoot -Parent
if (-not ('EzanCsv' -as [type])) {
    Add-Type -Path @((Join-Path $PSScriptRoot 'Data.cs'), (Join-Path $PSScriptRoot 'Update.cs'))
}

function ConvertTo-LocationKey {
    param ([string]$Name)
    [EzanCsv]::Key($Name)
}

function Test-EzanSummerPeriod {
    param ([datetime]$Date, [string]$SummerStart = '03-13', [string]$WinterStart = '11-07')
    foreach ($Boundary in @($SummerStart, $WinterStart)) {
        if ($Boundary -notmatch '^\d{2}-\d{2}$') { throw 'Dönem başlangıcı ay-gün biçiminde olmalı.' }
        $null = [datetime]::ParseExact('2001-' + $Boundary, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
    }
    if ($SummerStart -eq $WinterStart) { throw 'Yaz ve kış başlangıçları aynı gün olamaz.' }
    $Day = $Date.ToString('MM-dd', [Globalization.CultureInfo]::InvariantCulture)
    if ([string]::CompareOrdinal($SummerStart, $WinterStart) -lt 0) {
        return ([string]::CompareOrdinal($Day, $SummerStart) -ge 0 -and [string]::CompareOrdinal($Day, $WinterStart) -lt 0)
    }
    return ([string]::CompareOrdinal($Day, $SummerStart) -ge 0 -or [string]::CompareOrdinal($Day, $WinterStart) -lt 0)
}

function Get-DiyanetSchedule {
    param (
        [datetime]$Date = (Get-Date),
        [string]$Sehir = 'Istanbul',
        [string]$Ilce = 'Istanbul',
        [string]$CsvPath = (Join-Path $script:ProductRoot 'data/diyanet_namaz_vakitleri_turkiye.csv'),
        [string]$SummerStart = '03-13', [string]$WinterStart = '11-07'
    )
    $DateKey = $Date.ToString('yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
    $Row = [EzanCsv]::GetRow($CsvPath, $Sehir, $Ilce, $DateKey)
    $Summer = Test-EzanSummerPeriod -Date $Date -SummerStart $SummerStart -WinterStart $WinterStart
    $Fields = @('imsak', 'ogle', 'ikindi', 'aksam', 'yatsi')
    $Indexes = @(3, 5, 6, 7, 8)
    for ($i = 0; $i -lt 5; $i++) {
        $Time = $Row[$Indexes[$i]]
        if ($Time -notmatch '^([01][0-9]|2[0-3]):[0-5][0-9]$') { throw "CSV'de geçersiz $($Fields[$i]) vakti: $Time" }
        $At = [datetime]::ParseExact("$DateKey $Time", 'yyyy-MM-dd HH:mm', [Globalization.CultureInfo]::InvariantCulture)
        $Basis = 'Diyanet'
        if ($i -eq 0) {
            $Basis = 'İmsak'
            if ($Summer) {
                if ($Row[4] -notmatch '^([01][0-9]|2[0-3]):[0-5][0-9]$') { throw 'CSV güneş saati geçersiz.' }
                $At = [datetime]::ParseExact("$DateKey $($Row[4])", 'yyyy-MM-dd HH:mm', [Globalization.CultureInfo]::InvariantCulture).AddHours(-1)
                if ($At.Date -ne $Date.Date) { throw 'Sabah saati aynı gün içinde olmalı.' }
                $Time = $At.ToString('HH:mm'); $Basis = 'Güneşten 1 saat önce'
            }
        }
        [pscustomobject]@{
            Vakit = $Fields[$i]
            Saat = $Time
            Tarih = $At
            Basis = $Basis
        }
    }
}

function New-EzanState {
    @{
        Running = $false; Phase = 'stopped'; OriginalVolume = $null
        PrayerStart = [datetime]::MinValue; LastTriggered = ''; Schedule = @()
        ScheduleDate = [datetime]::MinValue; Error = ''; LastAttempt = [datetime]::MinValue
        MuteSeconds = 480; FadeOutSeconds = 60; FadeInSeconds = 30
        TestAt = $null; TestActive = $false; TestMuteSeconds = 480; TestFadeOutSeconds = 60
    }
}

function Open-EzanAudio {
    if (-not ('EzanAudio' -as [type])) { Add-Type -Path (Join-Path $PSScriptRoot 'Audio.cs') }
    [EzanAudio]::Begin()
}
function Write-EzanVolume { param ([float]$Volume) [EzanAudio]::Set($Volume) }
function Close-EzanAudio { if ('EzanAudio' -as [type]) { [EzanAudio]::End() } }

function Get-EzanUpcomingAction {
    param ([hashtable]$State, [datetime]$Now = (Get-Date))
    if ($null -ne $State.OriginalVolume -or $State.TestActive) { return $null }
    $At = $null; $Key = ''; $Label = ''; $IsTest = $false
    if ($null -ne $State.TestAt) {
        $At = $State.TestAt; $Key = 'test:' + $At.ToString('s'); $Label = 'Elle saat testi'; $IsTest = $true
    }
    if ($State.Running -and $State.ScheduleDate -eq $Now.Date) {
        $Prayer = $State.Schedule | Where-Object {
            $_.Tarih.ToString('s') -ne $State.LastTriggered -and $_.Tarih.AddMinutes(-1) -gt $Now
        } | Select-Object -First 1
        if ($Prayer -and ($null -eq $At -or $Prayer.Tarih.AddMinutes(-1) -lt $At)) {
            $At = $Prayer.Tarih.AddMinutes(-1); $Key = $Prayer.Tarih.ToString('s')
            $Label = $Prayer.Vakit + ' · ' + $Prayer.Saat; $IsTest = $false
        }
    }
    if ($null -eq $At -or $At -le $Now -or ($At - $Now).TotalSeconds -gt 15) { return $null }
    [pscustomobject]@{ Key = $Key; At = $At; Label = $Label; IsTest = $IsTest; Seconds = [int][Math]::Ceiling(($At - $Now).TotalSeconds) }
}

function Skip-EzanUpcomingAction {
    param ([hashtable]$State, [string]$Key, [datetime]$Now = (Get-Date))
    $Upcoming = Get-EzanUpcomingAction -State $State -Now $Now
    if ($null -eq $Upcoming -or $Upcoming.Key -ne $Key) { return $false }
    if ($Upcoming.IsTest) { Cancel-EzanTest $State }
    else { $State.LastTriggered = $Upcoming.Key }
    return $true
}

function Set-EzanTest {
    param (
        [hashtable]$State, [string]$Time,
        [int]$MuteSeconds = 480, [int]$FadeOutSeconds = 60,
        [datetime]$Now = (Get-Date)
    )
    if ($null -ne $State.OriginalVolume) { throw 'Devam eden ses geçişi bitince test planlayabilirsin.' }
    if ($MuteSeconds -lt 1 -or $MuteSeconds -gt 3600 -or $FadeOutSeconds -lt 0 -or $FadeOutSeconds -gt $MuteSeconds) { throw 'Test için ezan ve kısılma sürelerini kontrol edin.' }
    if ($Time -notmatch '^([01][0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9])?$') { throw 'Test saati HH:mm veya HH:mm:ss biçiminde olmalı.' }
    $Format = if ($Time.Length -eq 5) { 'HH:mm' } else { 'HH:mm:ss' }
    $Parsed = [datetime]::ParseExact($Time, $Format, [Globalization.CultureInfo]::InvariantCulture)
    $At = $Now.Date.Add($Parsed.TimeOfDay)
    if ($At -le $Now) { $At = $At.AddDays(1) }
    $State.TestAt = $At
    $State.TestMuteSeconds = $MuteSeconds; $State.TestFadeOutSeconds = $FadeOutSeconds
    $State.Error = ''
}

function Cancel-EzanTest {
    param ([hashtable]$State)
    if ($State.TestActive) {
        if ($null -ne $State.OriginalVolume) { Write-EzanVolume $State.OriginalVolume }
        $State.OriginalVolume = $null
        Close-EzanAudio
        $State.TestActive = $false
        $State.Phase = if ($State.Running) { 'waiting' } else { 'stopped' }
    }
    $State.TestAt = $null
}

function Stop-EzanTracking {
    param ([hashtable]$State)
    $State.Running = $false
    try {
        if ($null -ne $State.OriginalVolume) { Write-EzanVolume $State.OriginalVolume }
        $State.OriginalVolume = $null
        $State.TestAt = $null; $State.TestActive = $false
        $State.Phase = 'stopped'
        $State.Error = ''
    }
    catch {
        $State.Phase = 'error'
        $State.Error = "Ses geri yüklenemedi: $($_.Exception.Message)"
        throw
    }
    finally {
        # Başarısız geri yüklemede cihaz tutulur; kullanıcı yeniden deneyebilir.
        if ($null -eq $State.OriginalVolume) { Close-EzanAudio }
    }
}

function Update-EzanTracking {
    param ([hashtable]$State, [datetime]$Now = (Get-Date))
    if (-not $State.Running -and $null -eq $State.TestAt -and -not $State.TestActive) { return }
    try {
        if ($null -ne $State.OriginalVolume) {
            $Elapsed = ($Now - $State.PrayerStart).TotalSeconds
            $MuteSeconds = if ($State.TestActive) { $State.TestMuteSeconds } else { $State.MuteSeconds + 60 }
            $FadeOutSeconds = if ($State.TestActive) { $State.TestFadeOutSeconds } else { $State.FadeOutSeconds }
            if ($Elapsed -ge ($MuteSeconds + $State.FadeInSeconds)) {
                Write-EzanVolume $State.OriginalVolume
                $State.OriginalVolume = $null
                Close-EzanAudio
                $State.TestActive = $false
                $State.Phase = if ($State.Running) { 'waiting' } else { 'stopped' }
            }
            elseif ($Elapsed -ge $MuteSeconds) {
                $State.Phase = 'fade-in'
                Write-EzanVolume ([float]($State.OriginalVolume * (($Elapsed - $MuteSeconds) / $State.FadeInSeconds)))
            }
            elseif ($Elapsed -lt $FadeOutSeconds -and $FadeOutSeconds -gt 0) {
                $State.Phase = 'fade-out'
                Write-EzanVolume ([float]($State.OriginalVolume * (1 - [Math]::Max(0, $Elapsed) / $FadeOutSeconds)))
            }
            else { $State.Phase = 'muted'; Write-EzanVolume 0 }
            return
        }
        if ($null -ne $State.TestAt -and $Now -ge $State.TestAt) {
            $At = $State.TestAt
            $State.TestAt = $null
            if ($Now -lt $At.AddMinutes(1)) {
                $State.OriginalVolume = Open-EzanAudio
                $State.PrayerStart = $At
                $State.TestActive = $true
                Update-EzanTracking -State $State -Now $Now
                return
            }
        }
        if (-not $State.Running -or $State.ScheduleDate -ne $Now.Date) { return }
        $Prayer = $State.Schedule | Where-Object {
            $Now -ge $_.Tarih.AddMinutes(-1) -and $Now -lt $_.Tarih.AddMinutes(1) -and $_.Tarih.ToString('s') -ne $State.LastTriggered
        } | Select-Object -First 1
        if ($Prayer) {
            $State.OriginalVolume = Open-EzanAudio
            $State.LastTriggered = $Prayer.Tarih.ToString('s')
            $State.PrayerStart = $Prayer.Tarih.AddMinutes(-1)
            $State.Phase = 'fade-out'
            Update-EzanTracking -State $State -Now $Now
        }
    }
    catch {
        $Message = $_.Exception.Message
        try { Stop-EzanTracking $State } catch { $Message += " / $($_.Exception.Message)" }
        $State.Phase = 'error'; $State.Error = $Message
    }
}

function Get-EzanProgress {
    param ([hashtable]$State, [datetime]$Now = (Get-Date))
    if ($null -eq $State.OriginalVolume) { return $null }
    $Mute = if ($State.TestActive) { $State.TestMuteSeconds } else { $State.MuteSeconds + 60 }
    $FadeOut = if ($State.TestActive) { $State.TestFadeOutSeconds } else { $State.FadeOutSeconds }
    $Elapsed = [Math]::Max(0, ($Now - $State.PrayerStart).TotalSeconds)
    $Total = $Mute + $State.FadeInSeconds
    if ($Elapsed -lt $FadeOut) { $Step = 1; $Label = 'Ses kısılıyor'; $StageEnd = $FadeOut }
    elseif ($Elapsed -lt $Mute) { $Step = 2; $Label = 'Ezan süresi bekleniyor'; $StageEnd = $Mute }
    else { $Step = 3; $Label = 'Ses geri açılıyor'; $StageEnd = $Total }
    [pscustomobject]@{
        Step = $Step; Label = $Label
        RemainingSeconds = [int][Math]::Ceiling([Math]::Max(0, $StageEnd - $Elapsed))
        TotalRemainingSeconds = [int][Math]::Ceiling([Math]::Max(0, $Total - $Elapsed))
        Percent = [int][Math]::Floor([Math]::Min(100, $Elapsed / $Total * 100))
    }
}

function Format-EzanCountdown {
    param ([int]$Seconds)
    '{0:00}:{1:00}' -f [int][Math]::Floor($Seconds / 60), ($Seconds % 60)
}

function Read-EzanSettings {
    param ([string]$Directory)
    $Settings = @{ City = 'İSTANBUL'; District = 'İSTANBUL'; MuteSeconds = 480; FadeOutSeconds = 60; Tracking = $true; LastTriggered = ''; SummerStart = '03-13'; WinterStart = '11-07' }
    $Path = Join-Path $Directory 'settings.json'
    $LegacyPath = Join-Path $env:LOCALAPPDATA 'EzanVakti/settings.json'
    if (-not (Test-Path -LiteralPath $Path) -and
        [IO.Path]::GetFullPath($Directory).TrimEnd('\') -eq (Join-Path $env:LOCALAPPDATA 'Insat') -and
        (Test-Path -LiteralPath $LegacyPath)) { $Path = $LegacyPath }
    if (Test-Path -LiteralPath $Path) {
        $Saved = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
        foreach ($Key in @($Settings.Keys)) {
            if ($null -ne $Saved.PSObject.Properties[$Key]) { $Settings[$Key] = $Saved.$Key }
        }
        if ($Settings.MuteSeconds -notmatch '^\d+$' -or [int]$Settings.MuteSeconds -lt 1 -or [int]$Settings.MuteSeconds -gt 3600) { throw 'Ezan süresi ayarı geçersiz.' }
        if ($Settings.FadeOutSeconds -notmatch '^\d+$' -or [int]$Settings.FadeOutSeconds -gt [int]$Settings.MuteSeconds) { throw 'Sesi kısma süresi ayarı geçersiz.' }
        if ($Settings.Tracking -isnot [bool]) { throw 'Takip ayarı geçersiz.' }
    }
    $null = Test-EzanSummerPeriod -Date (Get-Date) -SummerStart $Settings.SummerStart -WinterStart $Settings.WinterStart
    return $Settings
}

function Save-EzanSettings {
    param ([hashtable]$Settings, [string]$Directory)
    [IO.Directory]::CreateDirectory($Directory) | Out-Null
    $Path = Join-Path $Directory 'settings.json'
    $Temp = Join-Path $Directory ('settings-' + [guid]::NewGuid() + '.tmp')
    try {
        [IO.File]::WriteAllText($Temp, ($Settings | ConvertTo-Json), (New-Object Text.UTF8Encoding($true)))
        if ([IO.File]::Exists($Path)) { [IO.File]::Replace($Temp, $Path, (Join-Path $Directory 'settings.backup.json')) }
        else { [IO.File]::Move($Temp, $Path) }
    }
    finally { if ([IO.File]::Exists($Temp)) { [IO.File]::Delete($Temp) } }
}

function Get-EzanStartupPath {
    Join-Path ([Environment]::GetFolderPath('Startup')) 'Insat.lnk'
}

function Set-EzanStartup {
    param ([bool]$Enabled)
    $Path = Get-EzanStartupPath
    if (-not $Enabled) {
        if (Test-Path -LiteralPath $Path) { Remove-Item -LiteralPath $Path -ErrorAction Stop }
        return
    }
    $Shell = New-Object -ComObject WScript.Shell
    $Shortcut = $null
    try {
        $Shortcut = $Shell.CreateShortcut($Path)
        $Shortcut.TargetPath = Join-Path $PSHOME 'powershell.exe'
        $Entry = Join-Path $script:ProductRoot 'insat.ps1'
        $Shortcut.Arguments = '-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $Entry + '" -Background'
        $Shortcut.WorkingDirectory = $script:ProductRoot
        $Shortcut.Description = 'Insat v1 — arka plan takibi'
        $Shortcut.IconLocation = (Join-Path $script:ProductRoot 'assets/insat.ico') + ',0'
        $Shortcut.WindowStyle = 7
        $Shortcut.Save()
    }
    finally {
        if ($null -ne $Shortcut) { [Runtime.InteropServices.Marshal]::ReleaseComObject($Shortcut) | Out-Null }
        [Runtime.InteropServices.Marshal]::ReleaseComObject($Shell) | Out-Null
    }
}

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
. (Join-Path $Root 'app/Core.ps1')
. (Join-Path $Root 'app/Update.ps1')
function Assert-True { param ([bool]$Value, [string]$Message) if (-not $Value) { throw $Message } }
function Assert-Throws {
    param ([scriptblock]$Action)
    $Thrown = $false
    try { & $Action | Out-Null } catch { $Thrown = $true }
    Assert-True $Thrown 'İşlemin reddedilmesi bekleniyordu.'
}
function New-YearHtml {
    param ([int]$Year)
    $Text = New-Object Text.StringBuilder
    $null = $Text.Append('<html><table id="yourTable"><tbody>')
    $Date = New-Object datetime($Year,1,1)
    while ($Date.Year -eq $Year) {
        $null = $Text.Append('<tr><td>')
        $null = $Text.Append($Date.ToString('dd MMMM yyyy dddd',[Globalization.CultureInfo]::GetCultureInfo('tr-TR')))
        $null = $Text.Append('</td><td>Hicri tarih</td><td>06:00</td><td>08:00</td><td>12:00</td><td>15:00</td><td>18:00</td><td>20:00</td></tr>')
        $Date = $Date.AddDays(1)
    }
    $null = $Text.Append('</tbody></table></html>')
    $Text.ToString()
}
$Run = Join-Path $PSScriptRoot ('.runtime/update-' + [guid]::NewGuid())
[IO.Directory]::CreateDirectory($Run) | Out-Null
$Html = New-YearHtml 2026
Assert-True ([InsatDiyanetData]::ReferenceUrl -eq 'https://namazvakitleri.diyanet.gov.tr/tr-TR/9541/istanbul-namaz-vakitleri') 'Resmi referans adresi yanlış.'
[InsatDiyanetData]::ValidateLocation('<link rel="canonical" href="https://namazvakitleri.diyanet.gov.tr/tr-TR/9541/istanbul-namaz-vakitleri">','9541')
Assert-Throws { [InsatDiyanetData]::ValidateLocation('<link rel="canonical" href="https://namazvakitleri.diyanet.gov.tr/tr-TR/9541/istanbul-namaz-vakitleri">','9220') }
Assert-Throws { [InsatDiyanetData]::ValidateLocation('<link rel="canonical" href="https://example.com/tr-TR/9541/istanbul">','9541') }
Assert-True ([InsatDiyanetData]::ParseYear($Html,2026).Count -eq 365) 'Normal yıl yanlış.'
Assert-True ([InsatDiyanetData]::ParseYear((New-YearHtml 2028),2028).Count -eq 366) 'Artık yıl yanlış.'
Assert-Throws { [InsatDiyanetData]::ParseYear($Html,2027) }
Assert-Throws { [InsatDiyanetData]::ParseYear('<html>Sunucu hatası</html>',2026) }
Assert-Throws { [InsatDiyanetData]::ParseYear($Html.Replace('06:00','25:00'),2026) }
Assert-Throws { [InsatDiyanetData]::ParseYear($Html.Replace('06:00','09:00'),2026) }
$FirstRow = [regex]::Match($Html,'<tr>.*?</tr>').Value
Assert-Throws { [InsatDiyanetData]::ParseYear($Html.Replace($FirstRow,''),2026) }
Assert-Throws { [InsatDiyanetData]::ParseYear($Html.Replace('</tbody>',($FirstRow + '</tbody>')),2026) }
$Active = Join-Path $Run 'vakitler.csv'
@('il,ilce,tarih,imsak,gunes,ogle,ikindi,aksam,yatsi',
    'İSTANBUL,İSTANBUL,2026-01-01,06:11,08:00,12:00,15:00,18:00,20:00',
    'ANKARA,ANKARA,2026-01-01,06:20,08:00,12:00,15:00,18:00,20:00',
    'İSTANBUL,İSTANBUL,2025-01-01,06:30,08:00,12:00,15:00,18:00,20:00') | Set-Content -LiteralPath $Active -Encoding UTF8
$Before = (Get-FileHash -LiteralPath $Active).Hash
$Pending = Join-Path $Run 'pending.csv'
$null = [InsatDiyanetData]::BuildCsv($Html,2026,'İSTANBUL','İSTANBUL',$Active,$Pending,[Threading.CancellationToken]::None)
Assert-True ((Get-FileHash -LiteralPath $Active).Hash -eq $Before) 'Hazırlama eski veriyi değiştirdi.'
Assert-True (@(Import-Csv -LiteralPath $Pending -Encoding UTF8).Count -eq 367) 'Başka bölge/yıl kayıtları korunmadı.'
$null = Complete-InsatCsvUpdate -PendingPath $Pending -TargetPath $Active -City Istanbul -District Istanbul -Year 2026
Assert-True ((Test-Path -LiteralPath ($Active + '.backup')) -and -not (Test-Path -LiteralPath $Pending)) 'Atomik değişim/yedek başarısız.'
$Times = @(Get-DiyanetSchedule -Date ([datetime]'2026-01-01') -CsvPath $Active)
Assert-True ($Times[0].Saat -eq '06:00') 'Yenilenen vakit etkinleşmedi.'
Assert-True (@(Get-DiyanetSchedule -Date ([datetime]'2026-01-01') -Sehir Ankara -Ilce Ankara -CsvPath $Active)[0].Saat -eq '06:20') 'Başka bölge değişti.'
Assert-True (@(Get-DiyanetSchedule -Date ([datetime]'2025-01-01') -CsvPath $Active)[0].Saat -eq '06:30') 'Önceki yıl değişti.'
$null = [InsatDiyanetData]::BuildCsv($Html,2026,'İSTANBUL','İSTANBUL',$Active,$Pending,[Threading.CancellationToken]::None)
Assert-True (@(Import-Csv -LiteralPath $Pending -Encoding UTF8).Count -eq 367) 'Tekrar güncelleme kopya üretti.'
$Before = (Get-FileHash -LiteralPath $Active).Hash
'bad,header' | Set-Content -LiteralPath $Pending -Encoding UTF8
Assert-Throws { Complete-InsatCsvUpdate -PendingPath $Pending -TargetPath $Active -City Istanbul -District Istanbul -Year 2026 }
Assert-True ((Get-FileHash -LiteralPath $Active).Hash -eq $Before) 'Bozuk güncelleme eski dosyayı değiştirdi.'
$Cancellation = New-Object Threading.CancellationTokenSource
try {
    $Cancellation.Cancel()
    Assert-Throws { [InsatDiyanetData]::BuildCsv($Html,2026,'İSTANBUL','İSTANBUL',$Active,$Pending,$Cancellation.Token) }
    Assert-True ((Get-FileHash -LiteralPath $Active).Hash -eq $Before) 'İptalde eski veri değişti.'
    Assert-True (-not (Test-Path -LiteralPath $Pending)) 'İptal edilen geçici dosya temizlenmedi.'
}
finally { $Cancellation.Dispose() }
$Location = Get-InsatDiyanetLocation -City Istanbul -District Istanbul
Assert-True ($Location.id -eq '9541') 'Diyanet kimliği yanlış.'
Assert-Throws { Get-InsatDiyanetLocation -City Istanbul -District Yok }
$UserData = Join-Path $Run 'user'
Assert-True ((Get-InsatCsvPath $UserData) -eq (Join-Path $Root 'data/diyanet_namaz_vakitleri_turkiye.csv')) 'Paket verisi bulunmadı.'
$UserCsv = Join-Path $UserData 'data/diyanet_namaz_vakitleri_turkiye.csv'
[IO.Directory]::CreateDirectory((Split-Path $UserCsv -Parent)) | Out-Null
Copy-Item -LiteralPath $Active -Destination $UserCsv
Assert-True ((Get-InsatCsvPath $UserData) -eq $UserCsv) 'Kullanıcı güncellemesi sonraki açılışta seçilmedi.'
Write-Output 'Güncelleme testleri başarılı: 365/366 gün, eksik/bozuk/yayımlanmamış yıl, bölge/yıl koruma, tekrar güncelleme, iptal, atomik dosya ve yedek.'

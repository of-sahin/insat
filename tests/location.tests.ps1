$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
. (Join-Path $Root 'app/Core.ps1')
. (Join-Path $Root 'app/Location.ps1')
function Assert-True { param ([bool]$Value, [string]$Message) if (-not $Value) { throw $Message } }
function Assert-Throws {
    param ([scriptblock]$Action)
    $Thrown = $false
    try { & $Action | Out-Null } catch { $Thrown = $true }
    Assert-True $Thrown 'İşlemin reddedilmesi bekleniyordu.'
}
Initialize-InsatLocation
$Database = New-Object InsatGeoDatabase((Join-Path $Root 'data/geography/provinces.geojson'), (Join-Path $Root 'data/geography/districts.geojson'))
$Locations = @{}
$Info = [EzanCsv]::Inspect((Join-Path $Root 'data/diyanet_namaz_vakitleri_turkiye.csv'))
foreach ($Pair in $Info.Locations) {
    $Parts = $Pair.Split('|')
    if (-not $Locations.ContainsKey($Parts[0])) { $Locations[$Parts[0]] = @() }
    $Locations[$Parts[0]] += $Parts[1]
}
$Ankara = $Database.Lookup(39.9208, 32.8541)
Assert-True ($Ankara.Province -eq 'Ankara' -and $Ankara.District -eq 'Çankaya') 'Ankara il/ilçe sınır eşleştirmesi yanlış.'
$Tuzla = $Database.Lookup(40.8167, 29.3)
Assert-True ($Tuzla.Province -eq 'İstanbul' -and $Tuzla.District -eq 'Tuzla') 'Tuzla il/ilçe sınır eşleştirmesi yanlış.'
$Result = Resolve-InsatLocation -Province $Tuzla.Province -District $Tuzla.District -Locations $Locations
Assert-True ($Result.City -eq 'İSTANBUL' -and $Result.District -eq 'TUZLA' -and -not $Result.IsCentralFallback) 'Doğrudan vakit bölgesi eşleşmedi.'
$Result = Resolve-InsatLocation -Province $Ankara.Province -District $Ankara.District -Locations $Locations
Assert-True ($Result.City -eq 'ANKARA' -and $Result.District -eq 'ANKARA' -and $Result.IsCentralFallback) 'Merkez önerisi açıkça işaretlenmedi.'
$Fatih = $Database.Lookup(41.0186, 28.9647)
$Result = Resolve-InsatLocation -Province $Fatih.Province -District $Fatih.District -Locations $Locations
Assert-True ($Result.City -eq 'İSTANBUL' -and $Result.District -eq 'İSTANBUL' -and $Result.IsCentralFallback) 'İstanbul merkez önerisi yanlış.'
Assert-Throws { $Database.Lookup(51.5074, -0.1278) }
Assert-Throws { $Database.Lookup([double]::NaN, 29) }
Assert-Throws { $Database.Lookup(91, 29) }
Assert-Throws { Resolve-InsatLocation -Province 'Londra' -District 'Merkez' -Locations $Locations }
Assert-Throws { Resolve-InsatLocation -Province 'Ankara' -District 'Bilinmeyen' -Locations @{ ANKARA = @('POLATLI') } }
$Result = Resolve-InsatLocation -Province 'İçel' -District 'Tarsus' -Locations @{ MERSİN = @('TARSUS') }
Assert-True ($Result.City -eq 'MERSİN' -and $Result.District -eq 'TARSUS') 'Eski il adı eşleşmedi.'
# Sistem konumunu okumadan Windows sağlayıcısının kurulup temizlenebilmesi sınanır.
$Reader = New-Object InsatPositionReader
try { Assert-True ($Reader.Poll().Status -eq 'Unavailable') 'Başlatılmamış sağlayıcı durumu yanlış.' }
finally { $Reader.Dispose() }
Write-Output 'Konum testleri başarılı: gerçek sınır geometrileri, il/ilçe eşleştirmesi, merkez önerisi, kapsam dışı koordinat ve Windows sağlayıcısı.'

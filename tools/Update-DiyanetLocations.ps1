param ([string]$OutputPath = (Join-Path (Split-Path $PSScriptRoot -Parent) 'data/diyanet_locations.json'))
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
$Base = 'https://namazvakitleri.diyanet.gov.tr/tr-TR/home/GetRegList'
function Read-OfficialList([string]$Uri) {
    $Response = Invoke-WebRequest -Uri $Uri -UseBasicParsing -TimeoutSec 30
    if ($Response.BaseResponse.ResponseUri.Host -ne 'namazvakitleri.diyanet.gov.tr') { throw 'Beklenmeyen kaynak.' }
    $Json = $Response.Content | ConvertFrom-Json
    if ($Json.Result -eq 'error') { throw 'Diyanet konum listesi alınamadı.' }
    $Json
}
$States = @( (Read-OfficialList ($Base + '?ChangeType=country&CountryId=2&Culture=tr-TR')).StateList )
if ($States.Count -ne 81) { throw 'Türkiye il listesi eksik; mevcut katalog korundu.' }
$Locations = New-Object 'System.Collections.Generic.List[object]'
$Ids = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($State in $States) {
    $Regions = @((Read-OfficialList ($Base + '?ChangeType=state&CountryId=2&Culture=tr-TR&StateId=' + $State.SehirID)).StateRegionList)
    if (-not $Regions.Count) { throw 'İlçe listesi eksik; mevcut katalog korundu.' }
    foreach ($Region in $Regions) {
        if (-not $Region.IlceAdi -or $Region.IlceID -notmatch '^\d+$' -or -not $Ids.Add([string]$Region.IlceID)) { throw 'Geçersiz/tekrarlı konum; mevcut katalog korundu.' }
        $Locations.Add([pscustomobject]@{ il = $State.SehirAdi; ilce = $Region.IlceAdi; id = [string]$Region.IlceID })
    }
    Write-Output ($State.SehirAdi + ': ' + $Regions.Count)
}
$Json = $Locations.ToArray() | Sort-Object il,ilce | ConvertTo-Json -Depth 3
$FullPath = [IO.Path]::GetFullPath($OutputPath)
[IO.Directory]::CreateDirectory((Split-Path $FullPath -Parent)) | Out-Null
$Pending = $FullPath + '.' + [guid]::NewGuid() + '.tmp'
$Backup = $Pending + '.backup'
try {
    [IO.File]::WriteAllText($Pending, $Json, (New-Object Text.UTF8Encoding($true)))
    if ([IO.File]::Exists($FullPath)) { [IO.File]::Replace($Pending, $FullPath, $Backup) }
    else { [IO.File]::Move($Pending, $FullPath) }
}
finally {
    if ([IO.File]::Exists($Pending)) { [IO.File]::Delete($Pending) }
    if ([IO.File]::Exists($Backup)) { [IO.File]::Delete($Backup) }
}
Write-Output ('Resmi Diyanet kataloğu: ' + $Locations.Count + ' konum')

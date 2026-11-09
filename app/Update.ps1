function Get-InsatCsvPath {
    param ([string]$DataDirectory = (Join-Path $env:LOCALAPPDATA 'Insat'))
    $Updated = Join-Path $DataDirectory 'data/diyanet_namaz_vakitleri_turkiye.csv'
    if (Test-Path -LiteralPath $Updated -PathType Leaf) { return $Updated }
    Join-Path $script:ProductRoot 'data/diyanet_namaz_vakitleri_turkiye.csv'
}

function Get-InsatDiyanetLocation {
    param ([string]$City, [string]$District)
    $CityKey = ConvertTo-LocationKey $City
    $DistrictKey = ConvertTo-LocationKey $District
    $Catalog = Get-Content -LiteralPath (Join-Path $script:ProductRoot 'data/diyanet_locations.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $Matches = @($Catalog | Where-Object { (ConvertTo-LocationKey $_.il) -eq $CityKey -and (ConvertTo-LocationKey $_.ilce) -eq $DistrictKey })
    if ($Matches.Count -ne 1) { throw 'Seçili il/ilçe için Diyanet konum kimliği bulunamadı.' }
    $Matches[0]
}

function Complete-InsatCsvUpdate {
    param ([string]$PendingPath, [string]$TargetPath, [string]$City, [string]$District, [int]$Year)
    if ([IO.Path]::GetFullPath($PendingPath) -eq [IO.Path]::GetFullPath($TargetPath)) { throw 'Geçici dosya ile etkin dosya aynı olamaz.' }
    $Info = [EzanCsv]::Inspect($PendingPath)
    $null = @(Get-DiyanetSchedule -Date (New-Object datetime($Year,1,1)) -Sehir $City -Ilce $District -CsvPath $PendingPath)
    $null = @(Get-DiyanetSchedule -Date (New-Object datetime($Year,12,31)) -Sehir $City -Ilce $District -CsvPath $PendingPath)
    [IO.Directory]::CreateDirectory((Split-Path ([IO.Path]::GetFullPath($TargetPath)) -Parent)) | Out-Null
    if ([IO.File]::Exists($TargetPath)) { [IO.File]::Replace($PendingPath, $TargetPath, ($TargetPath + '.backup')) }
    else { [IO.File]::Move($PendingPath, $TargetPath) }
    return $Info
}

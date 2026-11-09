param (
    [string]$City = 'Istanbul', [string]$District = 'Istanbul',
    [ValidateRange(2000,2100)][int]$Year = (Get-Date).Year,
    [string]$OutputPath,
    [string]$DataDirectory = (Join-Path $env:LOCALAPPDATA 'Insat')
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Core.ps1')
. (Join-Path $PSScriptRoot 'Update.ps1')
if (-not $OutputPath) { $OutputPath = Join-Path $DataDirectory 'data/diyanet_namaz_vakitleri_turkiye.csv' }
$OutputPath = [IO.Path]::GetFullPath($OutputPath)
[IO.Directory]::CreateDirectory((Split-Path $OutputPath -Parent)) | Out-Null
$Pending = Join-Path (Split-Path $OutputPath -Parent) ('update-' + [guid]::NewGuid() + '.csv.tmp')
$Job = $null
try {
    $Location = Get-InsatDiyanetLocation -City $City -District $District
    $Existing = if (Test-Path -LiteralPath $OutputPath) { $OutputPath } else { Get-InsatCsvPath $DataDirectory }
    $Job = New-Object InsatUpdateJob($Year, $Location.il, $Location.ilce, $Location.id, $Existing, $Pending)
    $Result = $Job.Task.GetAwaiter().GetResult()
    $null = Complete-InsatCsvUpdate -PendingPath $Pending -TargetPath $OutputPath -City $Location.il -District $Location.ilce -Year $Year
    Write-Output ("Güncellendi: {0} / {1}, {2}, {3} gün`n{4}`nKaynak: {5}" -f $Location.il,$Location.ilce,$Year,$Result.Days,$OutputPath,$Result.SourceUrl)
}
finally { if ($null -ne $Job) { $Job.Dispose() } }

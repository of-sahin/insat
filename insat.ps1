param (
    [string]$Sehir,
    [string]$Ilce,
    [string]$CsvPath,
    [ValidateRange(1, 3600)][int]$MuteDurationSeconds = 480,
    [ValidateRange(0, 3600)][int]$FadeOutDurationSeconds = 60,
    [switch]$CheckSchedule,
    [switch]$Background,
    [switch]$SmokeTest,
    [string]$DataDirectory = (Join-Path $env:LOCALAPPDATA 'Insat')
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'app/Core.ps1')
. (Join-Path $PSScriptRoot 'app/Update.ps1')
if (-not $CsvPath) { $CsvPath = Get-InsatCsvPath -DataDirectory $DataDirectory }
if ($CheckSchedule) {
    if (-not $Sehir) { $Sehir = 'Istanbul' }
    if (-not $Ilce) { $Ilce = 'Istanbul' }
    $ScheduleSettings = Read-EzanSettings $DataDirectory
    Get-DiyanetSchedule -Sehir $Sehir -Ilce $Ilce -CsvPath $CsvPath -SummerStart $ScheduleSettings.SummerStart -WinterStart $ScheduleSettings.WinterStart
    return
}
if ($FadeOutDurationSeconds -gt $MuteDurationSeconds) { throw 'Sesi kısma süresi ezan süresini aşamaz.' }
& (Join-Path $PSScriptRoot 'app/App.ps1') -Options $PSBoundParameters -CsvPath $CsvPath -DataDirectory $DataDirectory -Background:$Background -SmokeTest:$SmokeTest

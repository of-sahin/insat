$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
. (Join-Path $Root 'app/Core.ps1')
function Assert-True([bool]$Value, [string]$Message) { if (-not $Value) { throw $Message } }
function Assert-Throws([scriptblock]$Action) {
    $Thrown = $false
    try { & $Action | Out-Null } catch { $Thrown = $true }
    Assert-True $Thrown 'Expected invalid boundaries to be rejected.'
}
$Run = Join-Path $PSScriptRoot ('.runtime/morning-' + [guid]::NewGuid())
[IO.Directory]::CreateDirectory($Run) | Out-Null
$Csv = Join-Path $Run 'fixture.csv'
$Rows = @('il,ilce,tarih,imsak,gunes,ogle,ikindi,aksam,yatsi')
foreach ($Day in @('2026-01-01','2026-03-12','2026-03-13','2026-11-06','2026-11-07','2026-12-31','2028-02-29')) {
    $Rows += 'ISTANBUL,ISTANBUL,' + $Day + ',05:00,06:40,12:30,15:30,18:30,20:00'
}
$Rows | Set-Content -LiteralPath $Csv -Encoding UTF8
$Hash = (Get-FileHash -LiteralPath $Csv).Hash
foreach ($Day in @('2026-01-01','2026-03-12','2026-11-07','2026-12-31','2028-02-29')) {
    $Schedule = @(Get-DiyanetSchedule -Date ([datetime]$Day) -CsvPath $Csv)
    Assert-True ($Schedule[0].Saat -eq '05:00') ('Winter boundary failed: ' + $Day)
}
foreach ($Day in @('2026-03-13','2026-11-06')) {
    $Schedule = @(Get-DiyanetSchedule -Date ([datetime]$Day) -CsvPath $Csv)
    Assert-True ($Schedule.Count -eq 5 -and $Schedule[0].Saat -eq '05:40') ('Summer boundary failed: ' + $Day)
    Assert-True ($Schedule[0].Tarih -eq ([datetime]($Day + 'T05:40:00')) -and $Schedule[1].Saat -eq '12:30') 'Effective time/other prayers changed incorrectly.'
    $State = New-EzanState
    $State.Running = $true; $State.Schedule = $Schedule; $State.ScheduleDate = ([datetime]$Day).Date
    $Warning = Get-EzanUpcomingAction -State $State -Now ([datetime]($Day + 'T05:38:45'))
    Assert-True ($Warning.Seconds -eq 15) 'Warning did not follow the summer morning time.'
}
Assert-True (@(Get-DiyanetSchedule -Date ([datetime]'2026-03-13') -CsvPath $Csv -SummerStart '04-01')[0].Saat -eq '05:00') 'Custom summer start ignored.'
Assert-True (@(Get-DiyanetSchedule -Date ([datetime]'2026-11-07') -CsvPath $Csv -WinterStart '12-01')[0].Saat -eq '05:40') 'Custom winter start ignored.'
Assert-True (Test-EzanSummerPeriod -Date ([datetime]'2026-01-01') -SummerStart '11-07' -WinterStart '03-13') 'Year-wrapping custom period failed.'
Assert-Throws { Test-EzanSummerPeriod -Date (Get-Date) -SummerStart '02-29' }
Assert-Throws { Test-EzanSummerPeriod -Date (Get-Date) -SummerStart '13-01' }
Assert-Throws { Test-EzanSummerPeriod -Date (Get-Date) -SummerStart '11-07' }
$Settings = Read-EzanSettings $Run
Assert-True ($Settings.SummerStart -eq '03-13' -and $Settings.WinterStart -eq '11-07') 'Defaults incorrect.'
$Settings.SummerStart = '04-01'; $Settings.WinterStart = '12-01'
Save-EzanSettings $Settings $Run
$Saved = Read-EzanSettings $Run
Assert-True ($Saved.SummerStart -eq '04-01' -and $Saved.WinterStart -eq '12-01') 'Settings not persisted.'
'{"Tracking":false}' | Set-Content -LiteralPath (Join-Path $Run 'settings.json') -Encoding UTF8
$Legacy = Read-EzanSettings $Run
Assert-True ($Legacy.SummerStart -eq '03-13' -and $Legacy.WinterStart -eq '11-07' -and -not $Legacy.Tracking) 'Old settings migration failed.'
Assert-True ((Get-FileHash -LiteralPath $Csv).Hash -eq $Hash) 'Source CSV was modified.'
Write-Output 'Morning tests passed: boundaries, custom dates, leap day, warning time, persistence, old settings and unchanged CSV.'

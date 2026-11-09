$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
. (Join-Path $Root 'app/Install.ps1')
function Assert-True { param ([bool]$Value, [string]$Message) if (-not $Value) { throw $Message } }
function Assert-Throws {
    param ([scriptblock]$Action)
    $Thrown = $false
    try { & $Action | Out-Null } catch { $Thrown = $true }
    Assert-True $Thrown 'İşlemin reddedilmesi bekleniyordu.'
}
$Run = Join-Path $PSScriptRoot ('.runtime/setup test ' + [guid]::NewGuid())
$Target = Join-Path $Run 'Programs/Insat'
$Desktop = Join-Path $Run 'Desktop'
$Menu = Join-Path $Run 'StartMenu/Insat'
$Entry = Install-Insat -SourceRoot $Root -InstallDirectory $Target -DesktopDirectory $Desktop -MenuDirectory $Menu
Assert-True (Test-Path -LiteralPath $Entry) 'Uygulama kurulmadı.'
Assert-True (Test-Path -LiteralPath (Join-Path $Target 'assets/insat.ico')) 'İkon kurulumda kopyalanmadı.'
Assert-True (Test-Path -LiteralPath (Join-Path $Target 'app/Location.cs')) 'Konum sağlayıcısı kurulmadı.'
Assert-True (Test-Path -LiteralPath (Join-Path $Target 'app/Update.cs')) 'Güncelleyici kurulmadı.'
Assert-True (Test-Path -LiteralPath (Join-Path $Target 'data/diyanet_locations.json')) 'Diyanet konum kataloğu kurulmadı.'
Assert-True (Test-Path -LiteralPath (Join-Path $Target 'data/geography/districts.geojson')) 'Yerel konum verisi kurulmadı.'
Assert-True (Test-Path -LiteralPath (Join-Path $Target '.insat-install.json')) 'Kurulum kaydı yok.'
Assert-True (Test-Path -LiteralPath (Join-Path $Menu 'Insat kaldır.lnk')) 'Kaldırma kısayolu yok.'
$Shell = New-Object -ComObject WScript.Shell
$Shortcut = $Shell.CreateShortcut((Join-Path $Desktop 'Insat.lnk'))
try {
    Assert-True ($Shortcut.Arguments.Contains(('"' + $Entry + '"'))) 'Boşluklu kurulum yolu doğru tırnaklanmadı.'
    Assert-True ($Shortcut.TargetPath -eq (Join-Path $PSHOME 'powershell.exe')) 'Kısayol yanlış uygulamayı açıyor.'
    Assert-True ($Shortcut.IconLocation -eq ((Join-Path $Target 'assets/insat.ico') + ',0')) 'Kısayol kurulan uygulamanın ikonunu kullanmıyor.'
}
finally {
    [Runtime.InteropServices.Marshal]::ReleaseComObject($Shortcut) | Out-Null
    [Runtime.InteropServices.Marshal]::ReleaseComObject($Shell) | Out-Null
}
Assert-True (@(& $Entry -CheckSchedule).Count -eq 5) 'Kurulan uygulama veriyi okuyamadı.'
Install-Insat -SourceRoot $Root -InstallDirectory $Target -DesktopDirectory $Desktop -MenuDirectory $Menu | Out-Null
Assert-True (Test-Path -LiteralPath $Entry) 'Yeniden kurulum başarısız.'
$RecordPath = Join-Path $Target '.insat-install.json'
$Record = Get-Content -LiteralPath $RecordPath -Raw -Encoding UTF8 | ConvertFrom-Json
$Record.Directory = $Run
$Record | ConvertTo-Json | Set-Content -LiteralPath $RecordPath -Encoding UTF8
Assert-Throws { Uninstall-Insat -InstallDirectory $Target -StartupPath (Join-Path $Run 'startup.lnk') }
Assert-True (Test-Path -LiteralPath $Entry) 'Geçersiz kaldırma hedefi korunmadı.'
$Record.Directory = $Target
$Record | ConvertTo-Json | Set-Content -LiteralPath $RecordPath -Encoding UTF8
Uninstall-Insat -InstallDirectory $Target -StartupPath (Join-Path $Run 'startup.lnk')
Assert-True (-not (Test-Path -LiteralPath $Target)) 'Uygulama kaldırılmadı.'
Assert-True (-not (Test-Path -LiteralPath (Join-Path $Desktop 'Insat.lnk'))) 'Masaüstü kısayolu kaldırılmadı.'
Assert-True (-not (Test-Path -LiteralPath (Join-Path $Menu 'Insat.lnk'))) 'Başlat menüsü kısayolu kaldırılmadı.'
Install-Insat -SourceRoot $Root -InstallDirectory $Target -DesktopDirectory $Desktop -MenuDirectory $Menu -DesktopShortcut $false | Out-Null
Assert-True (-not (Test-Path -LiteralPath (Join-Path $Desktop 'Insat.lnk'))) 'İsteğe bağlı masaüstü seçimi çalışmadı.'
Uninstall-Insat -InstallDirectory $Target -StartupPath (Join-Path $Run 'startup.lnk')
[IO.Directory]::CreateDirectory($Target) | Out-Null
'koru' | Set-Content -LiteralPath (Join-Path $Target 'user.txt')
Assert-Throws { Install-Insat -SourceRoot $Root -InstallDirectory $Target -DesktopDirectory $Desktop -MenuDirectory $Menu }
Assert-True (Test-Path -LiteralPath (Join-Path $Target 'user.txt')) 'Alakasız hedef klasör korunmadı.'
Write-Output 'Kurulum testleri başarılı: dosyalar, masaüstü/Başlat kısayolları, boşluklu yol, tekrar kurulum, kaldırma ve hedef koruması.'

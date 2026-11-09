# Kullanıcıya özel kurulum. Windows kayıt defteri veya sistem klasörleri değiştirilmez.
function New-InsatShortcut {
    param ([string]$Path, [string]$Entry, [string]$Arguments = '')
    [IO.Directory]::CreateDirectory((Split-Path $Path -Parent)) | Out-Null
    $Shell = New-Object -ComObject WScript.Shell
    $Shortcut = $null
    try {
        $Shortcut = $Shell.CreateShortcut($Path)
        $Shortcut.TargetPath = Join-Path $PSHOME 'powershell.exe'
        $Shortcut.Arguments = '-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $Entry + '" ' + $Arguments
        $Shortcut.WorkingDirectory = Split-Path $Entry -Parent
        $Shortcut.Description = 'Insat — ezan vakti ses kontrolü'
        $EntryDirectory = Split-Path $Entry -Parent
        $IconPath = Join-Path $EntryDirectory 'assets/insat.ico'
        if (-not (Test-Path -LiteralPath $IconPath)) { $IconPath = Join-Path (Split-Path $EntryDirectory -Parent) 'assets/insat.ico' }
        if (-not (Test-Path -LiteralPath $IconPath)) { throw 'Insat ikon dosyası bulunamadı.' }
        $Shortcut.IconLocation = $IconPath + ',0'
        $Shortcut.WindowStyle = 7
        $Shortcut.Save()
    }
    finally {
        if ($null -ne $Shortcut) { [Runtime.InteropServices.Marshal]::ReleaseComObject($Shortcut) | Out-Null }
        [Runtime.InteropServices.Marshal]::ReleaseComObject($Shell) | Out-Null
    }
}

function Close-InsatForSetup {
    $Sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    # Yeniden adlandırmadan önceki v1 uygulaması çıkış komutunu desteklemiyordu.
    try { $Legacy = [Threading.EventWaitHandle]::OpenExisting("Local\EzanVakti.Open.v1.$Sid") }
    catch [Threading.WaitHandleCannotBeOpenedException] { $Legacy = $null }
    if ($null -ne $Legacy) {
        $Legacy.Set() | Out-Null; $Legacy.Dispose()
        throw 'Önce açık Ezan Vakti uygulamasında Tamamen çık seçeneğini kullanın, ardından tekrar Kur düğmesine basın.'
    }
    try { $Event = [Threading.EventWaitHandle]::OpenExisting("Local\Insat.Exit.v1.$Sid") }
    catch [Threading.WaitHandleCannotBeOpenedException] { return }
    try { $Event.Set() | Out-Null } finally { $Event.Dispose() }
    $Deadline = [datetime]::UtcNow.AddSeconds(8)
    do {
        Start-Sleep -Milliseconds 200
        $Mutex = $null
        try { $Mutex = [Threading.Mutex]::OpenExisting("Local\Insat.v1.$Sid") }
        catch [Threading.WaitHandleCannotBeOpenedException] { return }
        finally { if ($null -ne $Mutex) { $Mutex.Dispose() } }
    } while ([datetime]::UtcNow -lt $Deadline)
    throw 'Insat kapanamadı. Kontrol panelinden Tamamen çık seçeneğini kullanıp yeniden deneyin.'
}

function Install-Insat {
    param (
        [Parameter(Mandatory)][string]$SourceRoot,
        [string]$InstallDirectory = (Join-Path $env:LOCALAPPDATA 'Programs/Insat'),
        [string]$DesktopDirectory = ([Environment]::GetFolderPath('DesktopDirectory')),
        [string]$MenuDirectory = (Join-Path ([Environment]::GetFolderPath('Programs')) 'Insat'),
        [bool]$DesktopShortcut = $true
    )
    $SourceRoot = [IO.Path]::GetFullPath($SourceRoot).TrimEnd('\')
    $InstallDirectory = [IO.Path]::GetFullPath($InstallDirectory).TrimEnd('\')
    if ($SourceRoot -eq $InstallDirectory) { throw 'Kurulumu ZIP paketini çıkardığınız klasörden başlatın.' }
    $Files = @('Baslat.cmd','insat.ps1','VERSION','README.md','README.en.md','CHANGELOG.md',
        'app/App.ps1','app/Core.ps1','app/Data.cs','app/Audio.cs','app/Install.ps1','app/Setup.ps1', 'app/Location.cs', 'app/Location.ps1',
        'app/Update.cs','app/Update.ps1','app/Update-Data.ps1','data/diyanet_locations.json',
        'data/diyanet_namaz_vakitleri_turkiye.csv', 'assets/insat.ico',
        'data/geography/provinces.geojson','data/geography/districts.geojson','data/geography/sources.json','data/geography/README.md')
    foreach ($File in $Files) {
        if (-not (Test-Path -LiteralPath (Join-Path $SourceRoot $File) -PathType Leaf)) { throw "Kurulum dosyası eksik: $File" }
    }
    $Marker = Join-Path $InstallDirectory '.insat-install.json'
    if (Test-Path -LiteralPath $InstallDirectory) {
        if (((Get-Item -LiteralPath $InstallDirectory -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Kurulum hedefi bir bağlantı olamaz.' }
        if (-not (Test-Path -LiteralPath $Marker)) {
            if (@(Get-ChildItem -LiteralPath $InstallDirectory -Force).Count -gt 0) { throw 'Hedef klasör boş değil ve bir Insat kurulumu içermiyor.' }
        }
        else {
            $Existing = Get-Content -LiteralPath $Marker -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($Existing.Product -ne 'Insat' -or $Existing.Directory -ne $InstallDirectory) { throw 'Kurulum kaydı geçersiz.' }
        }
    }
    # İşaret baştan yazılır; yarım kalan kurulum aynı paketle onarılabilir.
    [IO.Directory]::CreateDirectory($InstallDirectory) | Out-Null
    $DesktopLink = Join-Path $DesktopDirectory 'Insat.lnk'
    $Record = @{
        Product = 'Insat'; Directory = $InstallDirectory
        Version = ([IO.File]::ReadAllText((Join-Path $SourceRoot 'VERSION')).Trim())
        DesktopLink = if ($DesktopShortcut) { $DesktopLink } elseif ($null -ne $Existing) { $Existing.DesktopLink } else { '' }
        MenuDirectory = $MenuDirectory
    }
    $Record | ConvertTo-Json | Set-Content -LiteralPath $Marker -Encoding UTF8
    foreach ($File in $Files) {
        $Destination = Join-Path $InstallDirectory $File
        [IO.Directory]::CreateDirectory((Split-Path $Destination -Parent)) | Out-Null
        Copy-Item -LiteralPath (Join-Path $SourceRoot $File) -Destination $Destination -Force -ErrorAction Stop
    }
    $Entry = Join-Path $InstallDirectory 'insat.ps1'
    if ($DesktopShortcut) { New-InsatShortcut -Path $DesktopLink -Entry $Entry }
    New-InsatShortcut -Path (Join-Path $MenuDirectory 'Insat.lnk') -Entry $Entry
    New-InsatShortcut -Path (Join-Path $MenuDirectory 'Insat kaldır.lnk') -Entry (Join-Path $InstallDirectory 'app/Setup.ps1') -Arguments '-Uninstall'
    return $Entry
}

function Uninstall-Insat {
    param (
        [string]$InstallDirectory = (Join-Path $env:LOCALAPPDATA 'Programs/Insat'),
        [string]$StartupPath = (Join-Path ([Environment]::GetFolderPath('Startup')) 'Insat.lnk')
    )
    # Silmeden önce çözülmüş tam hedef ve bu kuruluma ait işaret doğrulanır.
    $Target = [IO.Path]::GetFullPath($InstallDirectory).TrimEnd('\')
    if ([IO.Path]::GetFileName($Target) -ne 'Insat' -or -not [IO.Directory]::Exists($Target)) { throw 'Kaldırılacak Insat klasörü bulunamadı.' }
    $Record = Get-Content -LiteralPath (Join-Path $Target '.insat-install.json') -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json
    if ($Record.Product -ne 'Insat' -or $Record.Directory -ne $Target) { throw 'Kaldırma hedefi kurulum kaydıyla eşleşmiyor.' }
    $Shell = New-Object -ComObject WScript.Shell
    try {
        foreach ($Link in @($Record.DesktopLink, (Join-Path $Record.MenuDirectory 'Insat.lnk'), (Join-Path $Record.MenuDirectory 'Insat kaldır.lnk'), $StartupPath)) {
            if (-not $Link -or -not (Test-Path -LiteralPath $Link)) { continue }
            $Shortcut = $Shell.CreateShortcut($Link)
            try {
                # Başka bir konuma yönelen kısayol korunur.
                if ($Shortcut.Arguments.IndexOf(('"' + $Target + '\'), [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                    Remove-Item -LiteralPath $Link -ErrorAction Stop
                }
            }
            finally { [Runtime.InteropServices.Marshal]::ReleaseComObject($Shortcut) | Out-Null }
        }
    }
    finally { [Runtime.InteropServices.Marshal]::ReleaseComObject($Shell) | Out-Null }
    $Resolved = (Resolve-Path -LiteralPath $Target -ErrorAction Stop).Path.TrimEnd('\')
    if ($Resolved -ne $Target) { throw 'Kaldırma hedefi değişti; işlem durduruldu.' }
    if (((Get-Item -LiteralPath $Resolved -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or
        @(Get-ChildItem -LiteralPath $Resolved -Force -Recurse | Where-Object { ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 }).Count -gt 0) {
        throw 'Kurulum klasöründe bağlantı bulundu; otomatik kaldırma durduruldu.'
    }
    # Windows taraması kısa süreli dosya kilidi tutabilir; doğrulanmış aynı hedefte yeniden dene.
    for ($Attempt = 0; $Attempt -lt 4; $Attempt++) {
        try {
            Remove-Item -LiteralPath $Resolved -Recurse -Force -ErrorAction Stop
            break
        }
        catch [IO.IOException] {
            if ($Attempt -eq 3) { throw }
            Start-Sleep -Milliseconds 500
        }
    }
    if ((Test-Path -LiteralPath $Record.MenuDirectory -PathType Container) -and
        @(Get-ChildItem -LiteralPath $Record.MenuDirectory -Force).Count -eq 0) {
        Remove-Item -LiteralPath $Record.MenuDirectory -ErrorAction Stop
    }
}

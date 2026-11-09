param ([switch]$Uninstall, [switch]$SmokeTest, [string]$SnapshotPath)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
. (Join-Path $PSScriptRoot 'Install.ps1')
$Root = Split-Path $PSScriptRoot -Parent
$InstallDirectory = Join-Path $env:LOCALAPPDATA 'Programs/Insat'
if ($Uninstall) {
    try {
        $Answer = [Windows.Forms.MessageBox]::Show('Insat ve kısayolları kaldırılsın mı? Kişisel ayarların korunur.', 'Insat kaldır', 'YesNo', 'Question')
        if ($Answer -eq 'Yes') {
            Close-InsatForSetup
            Set-Location -LiteralPath $env:TEMP
            Uninstall-Insat -InstallDirectory $InstallDirectory
            [Windows.Forms.MessageBox]::Show('Insat kaldırıldı.', 'Insat', 'OK', 'Information') | Out-Null
        }
    }
    catch { [Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Insat', 'OK', 'Error') | Out-Null }
    return
}
$Form = New-Object Windows.Forms.Form
$Form.Text = 'Insat · Kurulum'
$SetupIcon = New-Object Drawing.Icon((Join-Path $Root 'assets/insat.ico'), 32, 32)
$Form.Icon = $SetupIcon
$Form.ClientSize = New-Object Drawing.Size(470, 285)
$Form.StartPosition = 'CenterScreen'; $Form.FormBorderStyle = 'FixedDialog'
$Form.MaximizeBox = $false; $Form.MinimizeBox = $false
$Form.Font = New-Object Drawing.Font('Segoe UI', 10)
$Form.BackColor = [Drawing.Color]::FromArgb(246, 248, 250)
$Title = New-Object Windows.Forms.Label
$Title.Text = 'Insat'; $Title.Font = New-Object Drawing.Font('Segoe UI', 23, [Drawing.FontStyle]::Bold)
$Title.SetBounds(24, 18, 420, 45)
$Intro = New-Object Windows.Forms.Label
$Intro.Text = 'Yalnızca senin Windows hesabına kurulur. Ek indirme ve yönetici izni gerekmez.'
$Intro.SetBounds(26, 76, 418, 50)
$Desktop = New-Object Windows.Forms.CheckBox
$Desktop.Text = 'Masaüstüne Insat kısayolu oluştur'; $Desktop.Checked = $true
$Desktop.SetBounds(26, 136, 418, 28)
$Open = New-Object Windows.Forms.CheckBox
$Open.Text = 'Kurulum bitince Insat uygulamasını aç'; $Open.Checked = $true
$Open.SetBounds(26, 169, 418, 28)
$Status = New-Object Windows.Forms.Label
$Status.Text = 'Bilgisayarla otomatik başlatmayı uygulamadan seçebilirsin.'
$Status.SetBounds(26, 211, 270, 54); $Status.Font = New-Object Drawing.Font('Segoe UI', 8)
$Button = New-Object Windows.Forms.Button
$Button.Text = 'Kur'; $Button.SetBounds(320, 219, 124, 40)
$Button.BackColor = [Drawing.Color]::FromArgb(20, 116, 104)
$Button.ForeColor = [Drawing.Color]::White; $Button.FlatStyle = 'Flat'
$Form.Controls.AddRange(@($Title,$Intro,$Desktop,$Open,$Status,$Button))
if ($SmokeTest) {
    try {
        $Form.Show(); [Windows.Forms.Application]::DoEvents()
        if ($SnapshotPath) {
            $Bitmap = New-Object Drawing.Bitmap($Form.Width, $Form.Height)
            try {
                $Form.DrawToBitmap($Bitmap, (New-Object Drawing.Rectangle(0, 0, $Form.Width, $Form.Height)))
                $Bitmap.Save($SnapshotPath, [Drawing.Imaging.ImageFormat]::Png)
            }
            finally { $Bitmap.Dispose() }
        }
        Write-Output 'Insat kurulum penceresi oluşturuldu; masaüstü kısayolu varsayılan olarak seçili.'
    }
    finally { $Form.Dispose(); $SetupIcon.Dispose() }
    return
}
$Button.Add_Click({
    $Button.Enabled = $false
    try {
        $Status.Text = 'Dosyalar kopyalanıyor…'
        [Windows.Forms.Application]::DoEvents()
        Close-InsatForSetup
        $Entry = Install-Insat -SourceRoot $Root -DesktopShortcut $Desktop.Checked
        # Önceki başlangıç tercihi varsa kısayolu kalıcı kurulum yoluna güncelle.
        $Startup = Join-Path ([Environment]::GetFolderPath('Startup')) 'Insat.lnk'
        if (Test-Path -LiteralPath $Startup) { New-InsatShortcut -Path $Startup -Entry $Entry -Arguments '-Background' }
        if ($Open.Checked) {
            Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -WindowStyle Hidden -ArgumentList ('-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $Entry + '"')
        }
        [Windows.Forms.MessageBox]::Show($Form, 'Kurulum tamamlandı. Insat kısayolundan açabilirsin.', 'Insat', 'OK', 'Information') | Out-Null
        $Form.Close()
    }
    catch { [Windows.Forms.MessageBox]::Show($Form, $_.Exception.Message, 'Kurulum tamamlanamadı', 'OK', 'Error') | Out-Null }
    finally { $Button.Enabled = $true }
})
try { [Windows.Forms.Application]::Run($Form) } finally { $Form.Dispose(); $SetupIcon.Dispose() }

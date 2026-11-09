param (
    [System.Collections.IDictionary]$Options,
    [string]$CsvPath,
    [string]$DataDirectory,
    [switch]$Background,
    [switch]$SmokeTest
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
. (Join-Path $PSScriptRoot 'Core.ps1')
. (Join-Path $PSScriptRoot 'Location.ps1')
. (Join-Path $PSScriptRoot 'Update.ps1')
$script:ActiveCsvPath = $CsvPath

$Mutex = $null; $Wake = $null; $Shutdown = $null; $Owned = $false; $Tray = $null; $Timer = $null; $Form = $null; $AppIcon = $null
$script:ExitRequested = $false
$script:UiReady = $false
$script:SoundNotice = $null
$script:State = New-EzanState
try {
    if (-not $SmokeTest) {
        $Identity = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        $Created = $false
        $Mutex = New-Object Threading.Mutex($true, "Local\Insat.v1.$Identity", [ref]$Created)
        if (-not $Created) {
            if (-not $Background) {
                for ($i = 0; $i -lt 20; $i++) {
                    try {
                        $Existing = [Threading.EventWaitHandle]::OpenExisting("Local\Insat.Open.v1.$Identity")
                        try { $Existing.Set() | Out-Null } finally { $Existing.Dispose() }
                        break
                    }
                    catch { if ($i -eq 19) { throw 'Çalışan uygulamaya ulaşılamadı. Birkaç saniye sonra tekrar açın.' }; Start-Sleep -Milliseconds 250 }
                }
            }
            return
        }
        $Owned = $true
        $Wake = New-Object Threading.EventWaitHandle($false, [Threading.EventResetMode]::AutoReset, "Local\Insat.Open.v1.$Identity")
        $Shutdown = New-Object Threading.EventWaitHandle($false, [Threading.EventResetMode]::AutoReset, "Local\Insat.Exit.v1.$Identity")
    }

    $script:Settings = Read-EzanSettings $DataDirectory
    if ($Options.ContainsKey('Sehir')) { $script:Settings.City = $Options['Sehir'] }
    if ($Options.ContainsKey('Ilce')) { $script:Settings.District = $Options['Ilce'] }
    if ($Options.ContainsKey('MuteDurationSeconds')) { $script:Settings.MuteSeconds = $Options['MuteDurationSeconds'] }
    if ($Options.ContainsKey('FadeOutDurationSeconds')) { $script:Settings.FadeOutSeconds = $Options['FadeOutDurationSeconds'] }
    if ([int]$script:Settings.FadeOutSeconds -gt [int]$script:Settings.MuteSeconds) { throw 'Sesi kısma süresi ezan süresini aşamaz.' }
    $Info = [EzanCsv]::Inspect($script:ActiveCsvPath)
    $script:Locations = @{}
    foreach ($Location in $Info.Locations) {
        $Parts = $Location.Split('|')
        if (-not $script:Locations.ContainsKey($Parts[0])) { $script:Locations[$Parts[0]] = New-Object 'System.Collections.Generic.List[string]' }
        $script:Locations[$Parts[0]].Add($Parts[1])
    }

    $Form = New-Object Windows.Forms.Form
    $ProductVersion = ([IO.File]::ReadAllText((Join-Path $script:ProductRoot 'VERSION'))).Trim()
    $Form.Text = 'Insat · v' + $ProductVersion
    $Form.ClientSize = New-Object Drawing.Size(560, 666)
    $Form.MinimumSize = $Form.Size
    $Form.MaximumSize = $Form.Size
    $Form.StartPosition = 'CenterScreen'
    $Form.FormBorderStyle = 'FixedSingle'
    $Form.MaximizeBox = $false
    $Form.AutoScaleMode = 'Dpi'
    $Form.Font = New-Object Drawing.Font('Segoe UI', 9)
    $Form.BackColor = [Drawing.Color]::FromArgb(246, 248, 250)
    $Form.ForeColor = [Drawing.Color]::FromArgb(30, 44, 56)
    $AppIcon = New-Object Drawing.Icon((Join-Path $script:ProductRoot 'assets/insat.ico'), 32, 32)
    $Form.Icon = $AppIcon

    function Add-UiControl {
        param ([string]$Type, [string]$Text, [int]$X, [int]$Y, [int]$Width, [int]$Height, $Parent = $Form)
        $Control = New-Object ("Windows.Forms.$Type")
        $Control.Text = $Text
        $Control.SetBounds($X, $Y, $Width, $Height)
        $Parent.Controls.Add($Control)
        return $Control
    }
    $Title = Add-UiControl Label 'Insat' 24 20 250 36
    $Title.Font = New-Object Drawing.Font('Segoe UI', 21, [Drawing.FontStyle]::Bold)
    $AboutLink = Add-UiControl LinkLabel 'Hakkında' 440 34 96 24
    $AboutLink.TextAlign = 'TopRight'
    $UpdateLink = Add-UiControl LinkLabel 'Vakitleri güncelle' 300 34 128 24
    $UpdateLink.TextAlign = 'TopRight'
    $Subtitle = Add-UiControl Label 'Vakitten 1 dakika önce sesi kısmaya başlar.' 27 60 510 23
    $Subtitle.ForeColor = [Drawing.Color]::FromArgb(93, 111, 125)
    $StatusCard = Add-UiControl Panel '' 24 94 512 74
    $StatusCard.BackColor = [Drawing.Color]::White
    $StatusLabel = Add-UiControl Label 'Hazırlanıyor…' 14 10 480 27 $StatusCard
    $StatusLabel.Font = New-Object Drawing.Font('Segoe UI', 12, [Drawing.FontStyle]::Bold)
    $NextLabel = Add-UiControl Label '' 14 42 480 23 $StatusCard
    $NextLabel.AutoEllipsis = $true
    $ProgressBar = Add-UiControl ProgressBar '' 14 66 480 5 $StatusCard
    $ProgressBar.Style = 'Continuous'; $ProgressBar.Visible = $false

    $null = Add-UiControl Label 'İl' 24 182 240 22
    $null = Add-UiControl Label 'İlçe / vakit bölgesi' 290 182 130 22
    $LocationLink = Add-UiControl LinkLabel 'Konumumu kullan' 422 181 114 23
    $City = Add-UiControl ComboBox '' 24 207 246 30
    $District = Add-UiControl ComboBox '' 290 207 246 30
    $City.DropDownStyle = 'DropDownList'; $District.DropDownStyle = 'DropDownList'
    $City.Items.AddRange([object[]]@($script:Locations.Keys | Sort-Object -Culture tr-TR))
    $DateLabel = Add-UiControl Label '' 24 252 392 23
    $DateLabel.Font = New-Object Drawing.Font('Segoe UI', 10, [Drawing.FontStyle]::Bold)
    $TestLink = Add-UiControl LinkLabel 'Elle test saati…' 424 253 112 23
    $Times = Add-UiControl ListView '' 24 279 512 145
    $Times.View = 'Details'; $Times.FullRowSelect = $true; $Times.HeaderStyle = 'Nonclickable'
    $Times.BorderStyle = 'None'; $Times.MultiSelect = $false
    $Times.Columns.Add('Vakit', 328) | Out-Null
    $Times.Columns.Add('Saat', 155) | Out-Null

    $null = Add-UiControl Label 'Ezan süresi (saniye)' 24 439 246 22
    $null = Add-UiControl Label 'Sesi kısma süresi (saniye)' 290 439 246 22
    $Duration = Add-UiControl NumericUpDown '' 24 464 246 29
    $FadeOut = Add-UiControl NumericUpDown '' 290 464 246 29
    $Duration.Minimum = 1; $Duration.Maximum = 3600; $Duration.Value = $script:Settings.MuteSeconds
    $FadeOut.Minimum = 0; $FadeOut.Maximum = 3600; $FadeOut.Value = $script:Settings.FadeOutSeconds
    $AutoStart = Add-UiControl CheckBox 'Bilgisayar açıldığında otomatik başlat' 24 506 352 27
    $MorningLink = Add-UiControl LinkLabel 'Sabah ezanı ayarları' 382 508 154 24
    $MorningLink.TextAlign = 'TopRight'
    $AutoStart.Checked = Test-Path -LiteralPath (Get-EzanStartupPath)
    $Hint = Add-UiControl Label 'Ezan bitiminde ses 30 saniyede geri gelir. × ile tepsiye küçülür.' 24 540 512 36
    $Hint.ForeColor = [Drawing.Color]::FromArgb(93, 111, 125)
    $StartButton = Add-UiControl Button 'Takibi başlat' 24 583 246 39
    $StopButton = Add-UiControl Button 'Takibi durdur' 290 583 246 39
    $StartButton.BackColor = [Drawing.Color]::FromArgb(20, 116, 104)
    $StartButton.ForeColor = [Drawing.Color]::White; $StartButton.FlatStyle = 'Flat'
    $ExitButton = Add-UiControl LinkLabel 'Tamamen çık' 24 638 126 22
    $Version = Add-UiControl Label ("v{0} · Veri: {1} — {2}" -f $ProductVersion, $Info.FirstDate, $Info.LastDate) 163 638 373 22
    $Version.TextAlign = 'TopRight'; $Version.ForeColor = $Hint.ForeColor

    $Tray = New-Object Windows.Forms.NotifyIcon
    $Tray.Icon = $Form.Icon; $Tray.Text = 'Insat — hazırlanıyor'
    $Menu = New-Object Windows.Forms.ContextMenuStrip
    $OpenItem = $Menu.Items.Add('Kontrol panelini aç')
    $StopItem = $Menu.Items.Add('Takibi durdur')
    $AboutItem = $Menu.Items.Add('Hakkında')
    $UpdateItem = $Menu.Items.Add('Vakit verisini güncelle')
    $Menu.Items.Add((New-Object Windows.Forms.ToolStripSeparator)) | Out-Null
    $ExitItem = $Menu.Items.Add('Tamamen çık')
    $Tray.ContextMenuStrip = $Menu

    function Show-ControlPanel {
        $Form.Show(); $Form.WindowState = 'Normal'; $Form.ShowInTaskbar = $true
        $Form.Activate(); $Form.BringToFront()
    }
    function Show-AppError {
        param ([string]$Message)
        if ($SmokeTest) { throw $Message }
        $StatusLabel.Text = 'İşlem tamamlanamadı'
        $NextLabel.Text = $Message
        [Windows.Forms.MessageBox]::Show($Form, $Message, 'Insat', 'OK', 'Warning') | Out-Null
    }
    function Save-AppSettings {
        $script:Settings.LastTriggered = $script:State.LastTriggered
        Save-EzanSettings $script:Settings $DataDirectory
    }
    function Show-AboutDialog {
        param ([switch]$TestOnly)
        $Dialog = New-Object Windows.Forms.Form
        $Dialog.Text = 'Insat · Hakkında'; $Dialog.Icon = $AppIcon
        $Dialog.ClientSize = New-Object Drawing.Size(500, 458)
        $Dialog.StartPosition = 'CenterParent'; $Dialog.FormBorderStyle = 'FixedDialog'
        $Dialog.MaximizeBox = $false; $Dialog.MinimizeBox = $false
        $Dialog.Font = $Form.Font; $Dialog.BackColor = $Form.BackColor
        $Logo = $AppIcon.ToBitmap()
        $Picture = Add-UiControl PictureBox '' 24 22 56 56 $Dialog
        $Picture.Image = $Logo; $Picture.SizeMode = 'Zoom'
        $NameLabel = Add-UiControl Label 'Insat' 98 20 378 36 $Dialog
        $NameLabel.Font = $Title.Font
        $VersionLabel = Add-UiControl Label ("Sürüm $ProductVersion") 100 62 376 23 $Dialog
        $Tabs = Add-UiControl TabControl '' 24 102 452 288 $Dialog
        $General = New-Object Windows.Forms.TabPage('Uygulama')
        $Privacy = New-Object Windows.Forms.TabPage('Veri ve gizlilik')
        $Tabs.TabPages.AddRange(@($General, $Privacy))
        $null = Add-UiControl Label 'Ezan vakitlerinde bilgisayarın sesini kısar; ayarlanan süre dolunca eski seviyesine geri getirir.' 16 18 410 44 $General
        $DataLabel = Add-UiControl Label ("Vakit verisinin kapsamı:`n$($Info.FirstDate) — $($Info.LastDate)`n`nKaydedilen bölge: $($script:Settings.City) / $($script:Settings.District)") 16 80 410 83 $General
        $null = Add-UiControl Label 'Destek: of.sahin@outlook.com' 16 164 410 23 $General
        $null = Add-UiControl Label 'Ses 30 saniyede geri açılır. Pencereyi kapattığında sistem tepsisinde çalışmaya devam eder.' 16 200 410 40 $General
        $SourcesText = "Güncelleme ve il/ilçe kataloğu: Diyanet resmi sitesi.`nInsat, Diyanet'in resmi uygulaması değildir.`n`nKonum eşleştirmesi bilgisayarda yapılır. Koordinatlar kaydedilmez; onaylanan il/vakit bölgesi saklanır.`n`nSınırlar: © OpenStreetMap contributors / geoBoundaries.`nADM1: CC BY-SA 2.0 · ADM2: ODbL 1.0.`n`nMikrofon kullanılmaz; konum yalnızca sen istediğinde alınır."
        $null = Add-UiControl Label $SourcesText 16 18 410 228 $Privacy
        $Help = Add-UiControl Button 'Kullanım kılavuzu' 24 408 220 32 $Dialog
        $Close = Add-UiControl Button 'Kapat' 320 408 156 32 $Dialog
        $Dialog.AcceptButton = $Close; $Dialog.CancelButton = $Close
        $Close.Add_Click({ $Dialog.Close() })
        $Help.Add_Click({
            try { Start-Process -FilePath (Join-Path $env:WINDIR 'System32/notepad.exe') -ArgumentList ('"' + (Join-Path $script:ProductRoot 'README.md') + '"') }
            catch { Show-AppError 'Kullanım kılavuzu açılamadı.' }
        })
        try {
            if ($TestOnly) {
                $Dialog.Show($Form); [Windows.Forms.Application]::DoEvents()
                if ($Tabs.TabPages.Count -ne 2 -or -not $VersionLabel.Text.Contains($ProductVersion) -or -not $DataLabel.Text.Contains($Info.LastDate)) { throw 'Hakkında bilgileri eksik.' }
                for ($Page = 0; $Page -lt $Tabs.TabPages.Count; $Page++) {
                    $Tabs.SelectedIndex = $Page
                    [Windows.Forms.Application]::DoEvents()
                    $Snapshot = New-Object Drawing.Bitmap($Dialog.Width, $Dialog.Height)
                    try {
                        $Dialog.DrawToBitmap($Snapshot, (New-Object Drawing.Rectangle(0, 0, $Dialog.Width, $Dialog.Height)))
                        $Snapshot.Save((Join-Path $DataDirectory "about-$Page.png"), [Drawing.Imaging.ImageFormat]::Png)
                    }
                    finally { $Snapshot.Dispose() }
                }
                $Close.PerformClick()
            }
            else { $Dialog.ShowDialog($Form) | Out-Null }
        }
        finally { $Dialog.Dispose(); $Logo.Dispose() }
    }
    $AboutLink.Add_LinkClicked({ Show-AboutDialog })
    $AboutItem.Add_Click({ Show-AboutDialog })
    function Show-DataUpdateDialog {
        param ([switch]$TestOnly)
        $Dialog = New-Object Windows.Forms.Form
        $Dialog.Text = 'Insat · Vakit verisini güncelle'; $Dialog.Icon = $AppIcon
        $Dialog.ClientSize = New-Object Drawing.Size(500, 328)
        $Dialog.StartPosition = 'CenterParent'; $Dialog.FormBorderStyle = 'FixedDialog'
        $Dialog.MaximizeBox = $false; $Dialog.MinimizeBox = $false
        $Dialog.Font = $Form.Font; $Dialog.BackColor = $Form.BackColor
        $null = Add-UiControl Label ("Seçili bölge: $($City.SelectedItem) / $($District.SelectedItem)") 22 20 456 24 $Dialog
        $null = Add-UiControl Label 'Yıl' 22 60 60 24 $Dialog
        $Year = Add-UiControl NumericUpDown '' 96 56 150 30 $Dialog
        $Year.Minimum = 2000; $Year.Maximum = 2100; $Year.Value = (Get-Date).Year
        $null = Add-UiControl Label 'Seçili bölgenin tam yıl verisi Diyanet resmi sayfasından indirilir. Diğer il/ilçe ve yıl kayıtları korunur. İnternet bağlantısı gerekir.' 22 101 456 52 $Dialog
        $Status = Add-UiControl Label 'Tam yıl doğrulanmadan mevcut CSV değiştirilmez.' 22 167 456 52 $Dialog
        $Bar = Add-UiControl ProgressBar '' 22 233 456 10 $Dialog
        $Bar.Style = 'Marquee'; $Bar.Visible = $false
        $Download = Add-UiControl Button 'Güncelle' 22 274 216 34 $Dialog
        $Cancel = Add-UiControl Button 'Kapat' 260 274 218 34 $Dialog
        $Download.BackColor = $StartButton.BackColor; $Download.ForeColor = $StartButton.ForeColor; $Download.FlatStyle = 'Flat'
        $Context = @{ Job = $null; Pending = ''; City = [string]$City.SelectedItem; District = [string]$District.SelectedItem; Year = [int]$Year.Value; Applied = $false }
        $Poll = New-Object Windows.Forms.Timer
        $Poll.Interval = 250
        function Apply-DownloadedData {
            $Target = Join-Path $DataDirectory 'data/diyanet_namaz_vakitleri_turkiye.csv'
            $UpdatedInfo = Complete-InsatCsvUpdate -PendingPath $Context.Pending -TargetPath $Target -City $Context.City -District $Context.District -Year $Context.Year
            $script:ActiveCsvPath = $Target
            $script:Info = $UpdatedInfo
            $Version.Text = "v{0} · Veri: {1} — {2}" -f $ProductVersion,$UpdatedInfo.FirstDate,$UpdatedInfo.LastDate
            $script:State.ScheduleDate = [datetime]::MinValue
            Load-Day
            $Context.Applied = $true
            $Status.Text = "$($Context.Year) yılı güncellendi. CSV kaydedildi; günlük vakitler yeniden yüklendi."
        }
        $Download.Add_Click({
            try {
                if ($script:State.Running -or $null -ne $script:State.OriginalVolume -or $null -ne $script:State.TestAt) { throw 'Güncellemeden önce takibi ve testi durdur.' }
                $Location = Get-InsatDiyanetLocation -City $Context.City -District $Context.District
                $Directory = Join-Path $DataDirectory 'data'
                [IO.Directory]::CreateDirectory($Directory) | Out-Null
                $Context.Year = [int]$Year.Value
                $Context.Pending = Join-Path $Directory ('update-' + [guid]::NewGuid() + '.csv.tmp')
                $Context.Job = New-Object InsatUpdateJob($Context.Year,$Context.City,$Context.District,$Location.id,$script:ActiveCsvPath,$Context.Pending)
                $Download.Enabled = $false; $Year.Enabled = $false; $Bar.Visible = $true; $Cancel.Text = 'İptal et'
                $Status.Text = 'Diyanet yıllık tablosu indiriliyor…'
                $Poll.Start()
            }
            catch { $Status.Text = $_.Exception.Message }
        })
        $Poll.Add_Tick({
            $Status.Text = $Context.Job.Status
            if (-not $Context.Job.Task.IsCompleted) { return }
            $Poll.Stop()
            try {
                $null = $Context.Job.Task.GetAwaiter().GetResult()
                Apply-DownloadedData
            }
            catch { $Status.Text = 'Güncellenemedi; mevcut CSV korundu. ' + $_.Exception.GetBaseException().Message }
            finally {
                $Context.Job.Dispose(); $Context.Job = $null
                $Download.Enabled = $true; $Year.Enabled = $true; $Bar.Visible = $false; $Cancel.Text = 'Kapat'
            }
        })
        $Cancel.Add_Click({ $Dialog.Close() })
        try {
            if ($TestOnly) {
                $Dialog.Show($Form); [Windows.Forms.Application]::DoEvents()
                $Context.Year = ([datetime]$Info.LastDate).Year
                $Year.Value = $Context.Year
                $Directory = Join-Path $DataDirectory 'data'
                [IO.Directory]::CreateDirectory($Directory) | Out-Null
                $Context.Pending = Join-Path $Directory ('update-' + [guid]::NewGuid() + '.csv.tmp')
                Copy-Item -LiteralPath $script:ActiveCsvPath -Destination $Context.Pending
                Apply-DownloadedData
                if (-not $Context.Applied -or -not (Test-Path -LiteralPath $script:ActiveCsvPath)) { throw 'Güncellenen CSV etkinleşmedi.' }
                $Snapshot = New-Object Drawing.Bitmap($Dialog.Width, $Dialog.Height)
                try {
                    $Dialog.DrawToBitmap($Snapshot, (New-Object Drawing.Rectangle(0, 0, $Dialog.Width, $Dialog.Height)))
                    $Snapshot.Save((Join-Path $DataDirectory 'data-update.png'), [Drawing.Imaging.ImageFormat]::Png)
                }
                finally { $Snapshot.Dispose() }
                $Cancel.PerformClick()
            }
            else { $Dialog.ShowDialog($Form) | Out-Null }
        }
        finally {
            $Poll.Stop(); $Poll.Dispose()
            if ($null -ne $Context.Job) { $Context.Job.Dispose() }
            $Dialog.Dispose()
        }
    }
    $UpdateLink.Add_LinkClicked({ Show-DataUpdateDialog })
    $UpdateItem.Add_Click({ Show-DataUpdateDialog })
    function Apply-DetectedLocation {
        param ($Candidate)
        if ($script:State.Running -or $null -ne $script:State.OriginalVolume -or $null -ne $script:State.TestAt) { throw 'Konumu değiştirmek için önce takibi ve testi durdur.' }
        $null = @(Get-DiyanetSchedule -Sehir $Candidate.City -Ilce $Candidate.District -CsvPath $script:ActiveCsvPath)
        $NewSettings = $script:Settings.Clone()
        $NewSettings.City = $Candidate.City; $NewSettings.District = $Candidate.District
        Save-EzanSettings $NewSettings $DataDirectory
        $script:Settings = $NewSettings
        $script:UiReady = $false
        try { $City.SelectedItem = $Candidate.City; $District.SelectedItem = $Candidate.District }
        finally { $script:UiReady = $true }
        Load-Day
    }
    function Show-LocationDialog {
        param ([switch]$TestOnly)
        $Dialog = New-Object Windows.Forms.Form
        $Dialog.Text = 'Insat · Bilgisayar konumu'
        $Dialog.ClientSize = New-Object Drawing.Size(480, 314)
        $Dialog.StartPosition = 'CenterParent'; $Dialog.FormBorderStyle = 'FixedDialog'
        $Dialog.MaximizeBox = $false; $Dialog.MinimizeBox = $false
        $Dialog.Font = $Form.Font; $Dialog.BackColor = $Form.BackColor; $Dialog.Icon = $AppIcon
        $Heading = Add-UiControl Label 'Konumuna göre vakit bölgesi' 22 18 436 30 $Dialog
        $Heading.Font = New-Object Drawing.Font('Segoe UI', 12, [Drawing.FontStyle]::Bold)
        $null = Add-UiControl Label 'Windows konum izni gerekir. Koordinatlar yalnızca bilgisayarında eşleştirilir; harici bir adres servisine gönderilmez.' 22 58 436 49 $Dialog
        $Message = Add-UiControl Label 'Windows konumu alınıyor…' 22 115 436 88 $Dialog
        $SettingsLink = Add-UiControl LinkLabel 'Windows konum ayarlarını aç' 22 205 436 22 $Dialog
        $Attribution = Add-UiControl Label 'Sınır verisi: © OpenStreetMap contributors / geoBoundaries' 22 234 436 22 $Dialog
        $Attribution.ForeColor = $Hint.ForeColor
        $Use = Add-UiControl Button 'Bu konumu kullan' 22 270 208 33 $Dialog
        $Cancel = Add-UiControl Button 'Vazgeç' 250 270 208 33 $Dialog
        $Use.BackColor = $StartButton.BackColor; $Use.ForeColor = $StartButton.ForeColor; $Use.FlatStyle = 'Flat'
        $Use.Enabled = $false
        $Context = @{ Reader = $null; Candidate = $null; Deadline = [datetime]::MaxValue }
        $LookupTimer = New-Object Windows.Forms.Timer
        $LookupTimer.Interval = 250
        function Stop-LocationReader {
            $LookupTimer.Stop()
            if ($null -ne $Context.Reader) { $Context.Reader.Dispose(); $Context.Reader = $null }
        }
        function Show-LocationFailure {
            param ([string]$Text)
            Stop-LocationReader
            $Context.Candidate = $null
            $Message.Text = $Text + "`nMevcut konum ayarın korundu; il/ilçeyi elle de seçebilirsin."
            $Use.Text = 'Tekrar dene'; $Use.Enabled = $true
        }
        function Receive-LocationPosition {
            param ($Position)
            if ($Position.Status -eq 'Denied') { throw 'Windows konum izni verilmedi. Konum ayarlarını kontrol et.' }
            if ($Position.Status -eq 'Unavailable') { throw 'Windows konum hizmeti kapalı veya konum sağlayıcısı kullanılamıyor.' }
            if ($Position.Status -ne 'Ready') { return }
            Stop-LocationReader
            if (-not [double]::IsNaN($Position.AccuracyMeters) -and $Position.AccuracyMeters -gt 25000) { throw 'Konum hassasiyeti il/ilçe seçmek için yetersiz.' }
            if ($null -eq $script:GeoDatabase) {
                $script:GeoDatabase = New-Object InsatGeoDatabase((Join-Path $script:ProductRoot 'data/geography/provinces.geojson'), (Join-Path $script:ProductRoot 'data/geography/districts.geojson'))
            }
            $Region = $script:GeoDatabase.Lookup($Position.Latitude, $Position.Longitude)
            $Context.Candidate = Resolve-InsatLocation -Province $Region.Province -District $Region.District -Locations $script:Locations
            $Candidate = $Context.Candidate
            $Text = "Bulunan: $($Region.Province) / $($Region.District)`nVakit bölgesi: $($Candidate.City) / $($Candidate.District)"
            if ($Candidate.IsCentralFallback) { $Text += "`nİlçe listede ayrı değil; il merkezi öneriliyor. Kontrol ederek onayla." }
            if (-not [double]::IsNaN($Position.AccuracyMeters)) { $Text += "`nYaklaşık konum hassasiyeti: $([Math]::Round($Position.AccuracyMeters)) m" }
            $Message.Text = $Text
            $Use.Text = 'Bu konumu kullan'; $Use.Enabled = $true
        }
        function Start-LocationLookup {
            try {
                Stop-LocationReader
                $Context.Candidate = $null
                $Use.Enabled = $false; $Use.Text = 'Bu konumu kullan'
                $Message.Text = 'Windows konumu alınıyor… En fazla 30 saniye sürebilir.'
                Initialize-InsatLocation
                $Context.Reader = New-Object InsatPositionReader
                $Context.Deadline = (Get-Date).AddSeconds(30)
                $Context.Reader.Start()
                $LookupTimer.Start()
            }
            catch { Show-LocationFailure $_.Exception.Message }
        }
        $LookupTimer.Add_Tick({
            try {
                if ((Get-Date) -ge $Context.Deadline) { throw '30 saniye içinde konum alınamadı. Windows konum ayarlarını kontrol et.' }
                Receive-LocationPosition $Context.Reader.Poll()
            }
            catch { Show-LocationFailure $_.Exception.Message }
        })
        $Use.Add_Click({
            if ($null -eq $Context.Candidate) { Start-LocationLookup; return }
            try { Apply-DetectedLocation $Context.Candidate; $Dialog.Close() }
            catch { $Message.Text = $_.Exception.Message }
        })
        $Cancel.Add_Click({ $Dialog.Close() })
        $SettingsLink.Add_LinkClicked({
            try { Start-Process 'ms-settings:privacy-location' }
            catch { $Message.Text = 'Windows Ayarlar > Gizlilik ve güvenlik > Konum bölümünü açabilirsin.' }
        })
        try {
            if ($TestOnly) {
                $Dialog.Show($Form); [Windows.Forms.Application]::DoEvents()
                Initialize-InsatLocation
                Show-LocationFailure 'Test: konum izni verilmedi.'
                if ($Context.Candidate -or -not $Message.Text.Contains('korundu')) { throw 'Konum hatası ayarı korumadı.' }
                Receive-LocationPosition ([pscustomobject]@{ Status = 'Ready'; Latitude = 39.9208; Longitude = 32.8541; AccuracyMeters = 100.0 })
                if ($null -eq $Context.Candidate) { throw 'Konum önerisi oluşturulamadı.' }
                $Snapshot = New-Object Drawing.Bitmap($Dialog.Width, $Dialog.Height)
                try {
                    $Dialog.DrawToBitmap($Snapshot, (New-Object Drawing.Rectangle(0, 0, $Dialog.Width, $Dialog.Height)))
                    $Snapshot.Save((Join-Path $DataDirectory 'location.png'), [Drawing.Imaging.ImageFormat]::Png)
                }
                finally { $Snapshot.Dispose() }
                $Use.PerformClick()
                if ($script:Settings.City -ne 'ANKARA' -or $City.SelectedItem -ne 'ANKARA' -or $District.SelectedItem -ne 'ANKARA') { throw 'Konum önerisi kaydedilmedi.' }
            }
            else {
                $Dialog.Add_Shown({ Start-LocationLookup })
                $Dialog.ShowDialog($Form) | Out-Null
            }
        }
        finally { Stop-LocationReader; $LookupTimer.Dispose(); $Dialog.Dispose() }
    }
    $LocationLink.Add_LinkClicked({ Show-LocationDialog })
    function Close-SoundNotice {
        if ($null -ne $script:SoundNotice) {
            $script:SoundNotice.Form.Dispose()
            $script:SoundNotice = $null
        }
    }
    function Update-SoundNotice {
        param ([datetime]$Now = (Get-Date), [switch]$TestOnly)
        $Upcoming = Get-EzanUpcomingAction -State $script:State -Now $Now
        if ($null -eq $Upcoming) { Close-SoundNotice; return }
        if ($null -ne $script:SoundNotice -and $script:SoundNotice.Key -ne $Upcoming.Key) { Close-SoundNotice }
        if ($null -eq $script:SoundNotice) {
            $Notice = New-Object Windows.Forms.Form
            $Notice.Text = 'Insat · Ses kısılacak'; $Notice.Icon = $AppIcon
            $Notice.ClientSize = New-Object Drawing.Size(420, 190)
            $Notice.StartPosition = 'CenterScreen'; $Notice.FormBorderStyle = 'FixedDialog'
            $Notice.ControlBox = $false; $Notice.TopMost = $true
            $Notice.Font = $Form.Font; $Notice.BackColor = $Form.BackColor
            $Countdown = Add-UiControl Label '' 22 20 376 34 $Notice
            $Countdown.Font = New-Object Drawing.Font('Segoe UI', 13, [Drawing.FontStyle]::Bold)
            $Detail = Add-UiControl Label '' 22 61 376 25 $Notice
            $null = Add-UiControl Label 'İptal ederseniz sonraki vakitlerin takibi devam eder.' 22 92 376 30 $Notice
            $Skip = Add-UiControl Button 'Bu seferlik iptal et' 22 136 376 34 $Notice
            $Skip.Add_Click({
                if ($null -eq $script:SoundNotice) { return }
                $ClickTime = if ($null -ne $script:SoundNotice.TestNow) { $script:SoundNotice.TestNow } else { Get-Date }
                if (Skip-EzanUpcomingAction -State $script:State -Key $script:SoundNotice.Key -Now $ClickTime) { Save-AppSettings }
                Close-SoundNotice
                Update-View
            })
            $script:SoundNotice = @{ Form = $Notice; Countdown = $Countdown; Detail = $Detail; Skip = $Skip; Key = $Upcoming.Key; TestNow = $(if ($TestOnly) { $Now } else { $null }) }
            $Notice.Show()
        }
        $script:SoundNotice.Countdown.Text = 'Ses {0} saniye sonra kısılacak.' -f $Upcoming.Seconds
        $script:SoundNotice.Detail.Text = $Upcoming.Label
    }
    function Show-MorningSettings {
        param ([switch]$TestOnly)
        $Dialog = New-Object Windows.Forms.Form
        $Dialog.Text = 'Insat · Sabah ezanı ayarları'; $Dialog.Icon = $AppIcon
        $Dialog.ClientSize = New-Object Drawing.Size(440, 294)
        $Dialog.StartPosition = 'CenterParent'; $Dialog.FormBorderStyle = 'FixedDialog'
        $Dialog.MaximizeBox = $false; $Dialog.MinimizeBox = $false
        $Dialog.Font = $Form.Font; $Dialog.BackColor = $Form.BackColor
        $null = Add-UiControl Label 'Yazın güneşten 1 saat önce, kışın imsak saati kullanılır. Başlangıç günleri her yıl geçerlidir.' 22 18 396 47 $Dialog
        $null = Add-UiControl Label 'Yaz dönemi başlangıcı' 22 82 190 23 $Dialog
        $null = Add-UiControl Label 'Kış dönemi başlangıcı' 234 82 184 23 $Dialog
        $SummerPicker = Add-UiControl DateTimePicker '' 22 111 184 28 $Dialog
        $WinterPicker = Add-UiControl DateTimePicker '' 234 111 184 28 $Dialog
        foreach ($Picker in @($SummerPicker, $WinterPicker)) {
            $Picker.Format = 'Custom'; $Picker.CustomFormat = 'dd.MM'; $Picker.ShowUpDown = $true
            $null = $Picker.Handle
        }
        $SummerPicker.Value = [datetime]::ParseExact('2001-' + $script:Settings.SummerStart, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
        $WinterPicker.Value = [datetime]::ParseExact('2001-' + $script:Settings.WinterStart, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
        $null = Add-UiControl Label 'Ses, hesaplanan sabah saatinden 1 dakika önce kısılmaya başlar. Uyarı bundan 15 saniye önce gösterilir.' 22 158 396 45 $Dialog
        $Defaults = Add-UiControl LinkLabel 'Varsayılanlar: 13 Mart / 7 Kasım' 22 211 396 23 $Dialog
        $Defaults.Add_LinkClicked({ $SummerPicker.Value = [datetime]'2001-03-13'; $WinterPicker.Value = [datetime]'2001-11-07' })
        $Save = Add-UiControl Button 'Kaydet' 22 247 184 32 $Dialog
        $Cancel = Add-UiControl Button 'Vazgeç' 234 247 184 32 $Dialog
        $Dialog.CancelButton = $Cancel
        $Cancel.Add_Click({ $Dialog.Close() })
        $Save.Add_Click({
            try {
                if (-not $MorningLink.Enabled) { throw 'Önce takibi ve varsa testi durdurun.' }
                $Summer = $SummerPicker.Value.ToString('MM-dd', [Globalization.CultureInfo]::InvariantCulture)
                $Winter = $WinterPicker.Value.ToString('MM-dd', [Globalization.CultureInfo]::InvariantCulture)
                $null = Test-EzanSummerPeriod -Date (Get-Date) -SummerStart $Summer -WinterStart $Winter
                $NewSettings = $script:Settings.Clone()
                $NewSettings.SummerStart = $Summer; $NewSettings.WinterStart = $Winter
                Save-EzanSettings $NewSettings $DataDirectory
                $script:Settings = $NewSettings
                Load-Day; Update-View; $Dialog.Close()
            }
            catch { Show-AppError $_.Exception.Message }
        })
        try {
            if ($TestOnly) {
                $Dialog.Show($Form); [Windows.Forms.Application]::DoEvents()
                if ($SummerPicker.Text -ne $SummerPicker.Value.ToString('dd.MM') -or $WinterPicker.Text -ne $WinterPicker.Value.ToString('dd.MM')) { throw 'Dönem tarihleri ekranda doğru gösterilmedi.' }
                $Bitmap = New-Object Drawing.Bitmap($Dialog.Width, $Dialog.Height)
                try {
                    $Dialog.DrawToBitmap($Bitmap, (New-Object Drawing.Rectangle(0, 0, $Bitmap.Width, $Bitmap.Height)))
                    $Bitmap.Save((Join-Path $DataDirectory 'morning-settings.png'), [Drawing.Imaging.ImageFormat]::Png)
                }
                finally { $Bitmap.Dispose() }
                $Save.PerformClick()
                if ($Dialog.Visible) { throw 'Sabah ayarları kaydedilemedi.' }
            }
            else { $Dialog.ShowDialog($Form) | Out-Null }
        }
        finally { $Dialog.Dispose() }
    }
    $MorningLink.Add_LinkClicked({ Show-MorningSettings })
    function Update-View {
        param ([datetime]$Now = (Get-Date))
        $Names = @{ stopped = 'Takip durduruldu'; waiting = 'Takip açık'; 'fade-out' = 'Vakit öncesi · ses kısılıyor'; muted = 'Ezan vakti · ses kısık'; 'fade-in' = 'Ses geri getiriliyor'; error = 'Takip durdu · kontrol gerekli' }
        $StatusLabel.Text = $Names[$script:State.Phase]
        if ($script:State.Phase -eq 'error' -and $script:State.Running) { $StatusLabel.Text = 'Vakit verisi bekleniyor' }
        if ($script:State.TestActive) { $StatusLabel.Text = 'Test · ' + $StatusLabel.Text }
        elseif ($null -ne $script:State.TestAt) { $StatusLabel.Text = 'Elle saat testi planlandı' }
        $StatusLabel.ForeColor = if ($script:State.Running) { [Drawing.Color]::FromArgb(20, 116, 104) } else { $Form.ForeColor }
        if ($null -ne $script:State.TestAt) { $NextLabel.Text = 'Tek seferlik test: ' + $script:State.TestAt.ToString('dd.MM.yyyy HH:mm:ss') }
        elseif ($script:State.TestActive) { $NextLabel.Text = 'Test çalışıyor. İptal etmek için Elle test saati bağlantısını kullan.' }
        elseif ($script:State.Error) { $NextLabel.Text = $script:State.Error }
        elseif (-not $script:State.Running) { $NextLabel.Text = 'Konumunu seçip Takibi başlat düğmesine bas.' }
        else {
            $Next = $script:State.Schedule | Where-Object { $_.Tarih -gt (Get-Date) } | Select-Object -First 1
            $NextLabel.Text = if ($Next) { "Sıradaki vakit: $($Next.Vakit) · $($Next.Saat)" } else { 'Bugünün vakitleri tamamlandı. Yarın otomatik yenilenir.' }
        }
        $Progress = Get-EzanProgress -State $script:State -Now $Now
        $ProgressBar.Visible = $null -ne $Progress
        if ($null -ne $Progress) {
            $Prefix = if ($script:State.TestActive) { 'Test' } else { 'Ezan' }
            $StatusLabel.Text = '{0} · {1}/3 {2}' -f $Prefix, $Progress.Step, $Progress.Label
            $NextLabel.Text = 'Bu aşama: {0} · Toplam kalan: {1} · %{2}' -f (Format-EzanCountdown $Progress.RemainingSeconds), (Format-EzanCountdown $Progress.TotalRemainingSeconds), $Progress.Percent
            $ProgressBar.Value = $Progress.Percent
        }
        else { $ProgressBar.Value = 0 }
        $Tray.Text = 'Insat — ' + $StatusLabel.Text
        $StartButton.Enabled = -not $script:State.Running -and -not $script:State.TestActive
        $StopButton.Enabled = $script:State.Running -or $null -ne $script:State.OriginalVolume -or $null -ne $script:State.TestAt
        $StopItem.Enabled = $StopButton.Enabled
        foreach ($Control in @($City, $District, $Duration, $FadeOut)) { $Control.Enabled = -not $script:State.Running -and -not $script:State.TestActive }
        $LocationLink.Enabled = -not $script:State.Running -and $null -eq $script:State.OriginalVolume -and $null -eq $script:State.TestAt
        $MorningLink.Enabled = $LocationLink.Enabled
        $UpdateLink.Enabled = $LocationLink.Enabled
        $UpdateItem.Enabled = $UpdateLink.Enabled
    }
    function Show-ManualTestDialog {
        param ([switch]$TestOnly)
        $Dialog = New-Object Windows.Forms.Form
        $Dialog.Text = 'Insat · Elle saat ile test'
        $Dialog.ClientSize = New-Object Drawing.Size(420, 252)
        $Dialog.StartPosition = 'CenterParent'; $Dialog.FormBorderStyle = 'FixedDialog'
        $Dialog.MaximizeBox = $false; $Dialog.MinimizeBox = $false
        $Dialog.Font = $Form.Font; $Dialog.BackColor = $Form.BackColor
        $null = Add-UiControl Label 'Tek seferlik test saati (HH:mm:ss)' 22 18 376 25 $Dialog
        $Picker = Add-UiControl DateTimePicker '' 22 49 376 30 $Dialog
        $Picker.Format = 'Custom'; $Picker.CustomFormat = 'HH:mm:ss'; $Picker.ShowUpDown = $true
        $Picker.Value = if ($null -ne $script:State.TestAt) { $script:State.TestAt } else { (Get-Date).AddMinutes(1) }
        $Description = Add-UiControl Label 'Ana ekrandaki sürelerle gerçek sesi kısar ve 30 saniyede geri açar. Geçmiş saat seçersen yarına planlanır.' 22 92 376 56 $Dialog
        $Description.ForeColor = $Hint.ForeColor
        $TestStatus = Add-UiControl Label '' 22 151 376 38 $Dialog
        $TestStatus.Text = if ($script:State.TestActive) { 'Test şu anda çalışıyor.' } elseif ($null -ne $script:State.TestAt) { 'Planlanan: ' + $script:State.TestAt.ToString('dd.MM.yyyy HH:mm:ss') } else { 'Test planlanmadı. Normal vakitler korunur.' }
        $Plan = Add-UiControl Button 'Testi planla' 22 199 178 34 $Dialog
        $Cancel = Add-UiControl Button 'Testi iptal et' 220 199 178 34 $Dialog
        $Plan.Enabled = $null -eq $script:State.OriginalVolume
        $Cancel.Enabled = $null -ne $script:State.TestAt -or $script:State.TestActive
        $Plan.BackColor = $StartButton.BackColor; $Plan.ForeColor = $StartButton.ForeColor; $Plan.FlatStyle = 'Flat'
        $Plan.Add_Click({
            try {
                Set-EzanTest -State $script:State -Time $Picker.Value.ToString('HH:mm:ss') -MuteSeconds ([int]$Duration.Value) -FadeOutSeconds ([int]$FadeOut.Value)
                Update-View
                $Dialog.Close()
            }
            catch { Show-AppError $_.Exception.Message }
        })
        $Cancel.Add_Click({
            try { Cancel-EzanTest $script:State; Update-View; $Dialog.Close() }
            catch { Show-AppError $_.Exception.Message }
        })
        try {
            if ($TestOnly) {
                $Dialog.Show($Form); [Windows.Forms.Application]::DoEvents()
                $Bitmap = New-Object Drawing.Bitmap($Dialog.Width, $Dialog.Height)
                try {
                    $Dialog.DrawToBitmap($Bitmap, (New-Object Drawing.Rectangle(0, 0, $Dialog.Width, $Dialog.Height)))
                    $Bitmap.Save((Join-Path $DataDirectory 'manual-test.png'), [Drawing.Imaging.ImageFormat]::Png)
                }
                finally { $Bitmap.Dispose() }
                $Plan.PerformClick()
                if ($null -eq $script:State.TestAt) { throw 'Arayüzden test planlanamadı.' }
                Cancel-EzanTest $script:State
                Update-View
            }
            else { $Dialog.ShowDialog($Form) | Out-Null }
        }
        finally { $Dialog.Dispose() }
    }
    $TestLink.Add_LinkClicked({ Show-ManualTestDialog })
    function Load-Day {
        $script:State.LastAttempt = Get-Date
        $script:State.Schedule = @()
        $script:State.ScheduleDate = [datetime]::MinValue
        $DateLabel.Text = (Get-Date).ToString('dd MMMM yyyy', [Globalization.CultureInfo]::GetCultureInfo('tr-TR')) + ' · Diyanet kaynaklı veri'
        $Times.Items.Clear()
        try {
            $Today = (Get-Date).Date
            $script:State.Schedule = @(Get-DiyanetSchedule -Date $Today -Sehir ([string]$City.SelectedItem) -Ilce ([string]$District.SelectedItem) -CsvPath $script:ActiveCsvPath -SummerStart $script:Settings.SummerStart -WinterStart $script:Settings.WinterStart)
            $script:State.ScheduleDate = $Today
            $Labels = @{ imsak = 'Sabah (imsak)'; ogle = 'Öğle'; ikindi = 'İkindi'; aksam = 'Akşam'; yatsi = 'Yatsı' }
            foreach ($Prayer in $script:State.Schedule) {
                $Label = if ($Prayer.Vakit -eq 'imsak') { 'Sabah (' + $Prayer.Basis.ToLower([Globalization.CultureInfo]::GetCultureInfo('tr-TR')) + ')' } else { $Labels[$Prayer.Vakit] }
                $Item = New-Object Windows.Forms.ListViewItem($Label)
                $Item.SubItems.Add($Prayer.Saat) | Out-Null
                $Times.Items.Add($Item) | Out-Null
            }
            $script:State.Error = ''
            $script:State.Phase = if ($script:State.Running) { 'waiting' } else { 'stopped' }
        }
        catch {
            $script:State.Error = $_.Exception.Message
            $script:State.Phase = 'error'
        }
        Update-View
    }
    function Stop-AppTracking {
        try {
            Stop-EzanTracking $script:State
            $script:Settings.Tracking = $false
            Save-AppSettings
            Update-View
        }
        catch { Show-AppError $_.Exception.Message }
    }
    function Exit-App {
        param ([switch]$PreserveTracking)
        $WasTracking = $script:State.Running
        Stop-AppTracking
        if ($null -ne $script:State.OriginalVolume) { return }
        if ($PreserveTracking -and $WasTracking) { $script:Settings.Tracking = $true; Save-AppSettings }
        $script:ExitRequested = $true
        $Form.Close()
    }

    $City.Add_SelectedIndexChanged({
        $District.Items.Clear()
        if ($null -ne $City.SelectedItem) {
            $District.Items.AddRange([object[]]$script:Locations[[string]$City.SelectedItem].ToArray())
            $District.SelectedIndex = 0
        }
    })
    $District.Add_SelectedIndexChanged({ if ($script:UiReady) { Load-Day } })
    $SelectedCity = @($City.Items | Where-Object { (ConvertTo-LocationKey $_) -eq (ConvertTo-LocationKey $script:Settings.City) })
    if ($SelectedCity.Count -ne 1) { throw "Kayıtlı il veride bulunamadı: $($script:Settings.City)" }
    $City.SelectedItem = $SelectedCity[0]
    $SelectedDistrict = @($District.Items | Where-Object { (ConvertTo-LocationKey $_) -eq (ConvertTo-LocationKey $script:Settings.District) })
    if ($SelectedDistrict.Count -ne 1) { throw "Kayıtlı ilçe veride bulunamadı: $($script:Settings.District)" }
    $District.SelectedItem = $SelectedDistrict[0]

    $StartAction = {
        try {
            if ($FadeOut.Value -gt $Duration.Value) { throw 'Sesi kısma süresi ezan süresinden uzun olamaz.' }
            if ($null -ne $script:State.OriginalVolume) { Stop-EzanTracking $script:State }
            Load-Day
            if ($script:State.ScheduleDate -ne (Get-Date).Date) { throw $script:State.Error }
            $script:Settings.City = [string]$City.SelectedItem
            $script:Settings.District = [string]$District.SelectedItem
            $script:Settings.MuteSeconds = [int]$Duration.Value
            $script:Settings.FadeOutSeconds = [int]$FadeOut.Value
            $script:Settings.Tracking = $true
            Save-AppSettings
            $script:State.MuteSeconds = [int]$Duration.Value
            $script:State.FadeOutSeconds = [int]$FadeOut.Value
            $script:State.Running = $true; $script:State.Phase = 'waiting'
            Update-View
        }
        catch { Show-AppError $_.Exception.Message }
    }
    $StartButton.Add_Click($StartAction)
    $StopButton.Add_Click({ Stop-AppTracking })
    $StopItem.Add_Click({ Stop-AppTracking })
    $ExitButton.Add_Click({ Exit-App })
    $ExitItem.Add_Click({ Exit-App })
    $OpenItem.Add_Click({ Show-ControlPanel })
    $Tray.Add_DoubleClick({ Show-ControlPanel })
    $AutoStart.Add_CheckedChanged({
        if (-not $script:UiReady) { return }
        try { Set-EzanStartup $AutoStart.Checked }
        catch {
            $script:UiReady = $false
            $AutoStart.Checked = Test-Path -LiteralPath (Get-EzanStartupPath)
            $script:UiReady = $true
            Show-AppError $_.Exception.Message
        }
    })
    $Form.Add_FormClosing({
        param ($Sender, $EventArgs)
        if (-not $script:ExitRequested -and $EventArgs.CloseReason -eq [Windows.Forms.CloseReason]::UserClosing) {
            $EventArgs.Cancel = $true
            $Form.Hide(); $Form.ShowInTaskbar = $false
            $Tray.ShowBalloonTip(2500, 'Insat', 'Kontrol paneli tepside. Yeniden açmak için uygulamayı veya tepsi simgesini kullan.', [Windows.Forms.ToolTipIcon]::Info)
        }
        else { try { Stop-EzanTracking $script:State } catch { } }
    })
    $script:State.LastTriggered = [string]$script:Settings.LastTriggered
    $script:UiReady = $true
    Load-Day
    $Timer = New-Object Windows.Forms.Timer
    $Timer.Interval = 250
    $Timer.Add_Tick({
        try {
            if ($null -ne $Wake -and $Wake.WaitOne(0)) { Show-ControlPanel }
            if ($null -ne $Shutdown -and $Shutdown.WaitOne(0)) { Exit-App -PreserveTracking; return }
            $Now = Get-Date
            if ($script:State.ScheduleDate -ne $Now.Date -and ($Now - $script:State.LastAttempt).TotalSeconds -ge 60 -and $null -eq $script:State.OriginalVolume) { Load-Day }
            $PreviousTrigger = $script:State.LastTriggered
            Update-EzanTracking -State $script:State -Now $Now
            if ($PreviousTrigger -ne $script:State.LastTriggered) { Save-AppSettings }
            Update-SoundNotice -Now $Now
            Update-View
        }
        catch {
            $Message = $_.Exception.Message
            try { Stop-EzanTracking $script:State } catch { }
            $script:State.Error = $Message; $script:State.Phase = 'error'
            Update-View
        }
    })
    if ($SmokeTest) {
        $Form.Show()
        [Windows.Forms.Application]::DoEvents()
        if (-not $Form.Controls.Contains($StartButton) -or $Times.Items.Count -ne 5) { throw "Arayüz veya günlük vakitler oluşturulamadı. Vakit: $($Times.Items.Count), hata: $($script:State.Error)" }
        if ($AutoStart.Checked -ne (Test-Path -LiteralPath (Get-EzanStartupPath))) { throw 'Başlangıç durumu tutarsız.' }
        $StartButton.PerformClick()
        if (-not $script:State.Running) { throw 'Arayüzden takip başlatılamadı.' }
        $StopButton.PerformClick()
        if ($script:State.Running) { throw 'Arayüzden takip durdurulamadı.' }
        Show-DataUpdateDialog -TestOnly
        Show-AboutDialog -TestOnly
        Show-LocationDialog -TestOnly
        Show-ManualTestDialog -TestOnly
        Show-MorningSettings -TestOnly
        $NoticeSavedState = $script:State
        try {
            $NoticeNow = Get-Date
            $script:State = New-EzanState
            $script:State.Running = $true; $script:State.ScheduleDate = $NoticeNow.Date
            $script:State.Schedule = @([pscustomobject]@{ Tarih = $NoticeNow.AddSeconds(75); Vakit = 'Akşam'; Saat = $NoticeNow.AddSeconds(75).ToString('HH:mm') })
            Update-SoundNotice -Now $NoticeNow -TestOnly
            [Windows.Forms.Application]::DoEvents()
            if ($null -eq $script:SoundNotice -or $script:SoundNotice.Countdown.Text -ne 'Ses 15 saniye sonra kısılacak.') { throw 'Ses uyarısı oluşturulamadı.' }
            $Snapshot = New-Object Drawing.Bitmap($script:SoundNotice.Form.Width, $script:SoundNotice.Form.Height)
            try {
                $script:SoundNotice.Form.DrawToBitmap($Snapshot, (New-Object Drawing.Rectangle(0, 0, $Snapshot.Width, $Snapshot.Height)))
                $Snapshot.Save((Join-Path $DataDirectory 'sound-notice.png'), [Drawing.Imaging.ImageFormat]::Png)
            }
            finally { $Snapshot.Dispose() }
            Update-SoundNotice -Now $NoticeNow.AddSeconds(15) -TestOnly
            if ($null -ne $script:SoundNotice) { throw 'Başlangıçta uyarı kapanmadı.' }
            $Form.Hide()
            Update-SoundNotice -Now $NoticeNow -TestOnly
            if (-not $script:SoundNotice.Form.Visible) { throw 'Tepsideyken uyarı görünmedi.' }
            $Form.Show()
            $script:SoundNotice.Skip.PerformClick()
            if ($null -ne $script:SoundNotice -or -not $script:State.Running -or -not $script:State.LastTriggered) { throw 'Uyarıdan tek seferlik iptal çalışmadı.' }
            Update-SoundNotice -Now $NoticeNow.AddSeconds(1) -TestOnly
            if ($null -ne $script:SoundNotice) { throw 'İptal edilen uyarı tekrar açıldı.' }
        }
        finally { Close-SoundNotice; $script:State = $NoticeSavedState; Save-AppSettings; Update-View }
        $SavedState = $script:State
        try {
            $script:State = New-EzanState
            $script:State.Running = $true; $script:State.TestActive = $true
            $script:State.TestMuteSeconds = 480; $script:State.TestFadeOutSeconds = 60
            $script:State.OriginalVolume = 0.8
            $PreviewNow = Get-Date
            $Offsets = @(30, 100, 495)
            for ($i = 0; $i -lt $Offsets.Count; $i++) {
                $script:State.PrayerStart = $PreviewNow.AddSeconds(-$Offsets[$i])
                Update-View -Now $PreviewNow
                $Step = $i + 1
                if (-not $ProgressBar.Visible -or -not $StatusLabel.Text.Contains("$Step/3") -or -not $NextLabel.Text.Contains('Toplam kalan:')) { throw "İlerleme arayüzü aşama $Step için hatalı." }
                $Preview = New-Object Drawing.Bitmap($Form.Width, $Form.Height)
                try {
                    $Form.DrawToBitmap($Preview, (New-Object Drawing.Rectangle(0, 0, $Form.Width, $Form.Height)))
                    $Preview.Save((Join-Path $DataDirectory "progress-$Step.png"), [Drawing.Imaging.ImageFormat]::Png)
                }
                finally { $Preview.Dispose() }
            }
        }
        finally { $script:State = $SavedState; Update-View }
        if ($ProgressBar.Visible -or $ProgressBar.Value -ne 0) { throw 'İşlem dışında ilerleme çubuğu gizlenmedi.' }
        $Bitmap = New-Object Drawing.Bitmap($Form.Width, $Form.Height)
        try {
            $Form.DrawToBitmap($Bitmap, (New-Object Drawing.Rectangle(0, 0, $Form.Width, $Form.Height)))
            $Bitmap.Save((Join-Path $DataDirectory 'ui.png'), [Drawing.Imaging.ImageFormat]::Png)
        }
        finally { $Bitmap.Dispose() }
        Write-Output 'Arayüz testi başarılı: konum, beş vakit, başlat/durdur, başlangıç durumu.'
        return
    }
    $Tray.Visible = $true
    $Form.Add_Shown({
        if ($script:Settings.Tracking) { $StartButton.PerformClick() }
        if ($Background) { $Form.Hide(); $Form.ShowInTaskbar = $false }
    })
    $Timer.Start()
    [Windows.Forms.Application]::Run($Form)
}
catch {
    $Message = $_.Exception.Message
    if ($SmokeTest) { throw }
    try {
        [IO.Directory]::CreateDirectory($DataDirectory) | Out-Null
        [IO.File]::AppendAllText((Join-Path $DataDirectory 'error.log'), ((Get-Date).ToString('s') + ' ' + $Message + [Environment]::NewLine))
    } catch { }
    [Windows.Forms.MessageBox]::Show("Uygulama açılamadı.`n`n$Message`n`nAyar dosyası: $DataDirectory", 'Insat', 'OK', 'Error') | Out-Null
}
finally {
    if ($null -ne $script:SoundNotice) { $script:SoundNotice.Form.Dispose(); $script:SoundNotice = $null }
    if ($null -ne $Timer) { $Timer.Stop(); $Timer.Dispose() }
    if ($null -ne $script:State.OriginalVolume) { try { Stop-EzanTracking $script:State } catch { } }
    if ($null -ne $Tray) { $Tray.Visible = $false; $Tray.Dispose() }
    if ($null -ne $Form) { $Form.Dispose() }
    if ($null -ne $AppIcon) { $AppIcon.Dispose() }
    if ($null -ne $Wake) { $Wake.Dispose() }
    if ($null -ne $Shutdown) { $Shutdown.Dispose() }
    if ($Owned) { $Mutex.ReleaseMutex() }
    if ($null -ne $Mutex) { $Mutex.Dispose() }
}

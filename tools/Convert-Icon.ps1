param (
    [Parameter(Mandatory)][string]$SourcePath,
    [string]$OutputPath = (Join-Path (Split-Path $PSScriptRoot -Parent) 'assets/insat.ico')
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
[IO.Directory]::CreateDirectory((Split-Path ([IO.Path]::GetFullPath($OutputPath)) -Parent)) | Out-Null
$Source = [Drawing.Image]::FromFile([IO.Path]::GetFullPath($SourcePath))
$Entries = New-Object 'System.Collections.Generic.List[object]'
try {
    foreach ($Size in @(16, 20, 24, 32, 40, 48, 64, 128, 256)) {
        $Bitmap = New-Object Drawing.Bitmap($Size, $Size, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $Graphics = [Drawing.Graphics]::FromImage($Bitmap)
        $Stream = New-Object IO.MemoryStream
        try {
            $Graphics.InterpolationMode = 'HighQualityBicubic'
            $Graphics.PixelOffsetMode = 'HighQuality'
            $Graphics.CompositingQuality = 'HighQuality'
            $Graphics.DrawImage($Source, (New-Object Drawing.Rectangle(0, 0, $Size, $Size)))
            $Graphics.Dispose(); $Graphics = $null
            if ($Size -eq 256) {
                $Bitmap.Save($Stream, [Drawing.Imaging.ImageFormat]::Png)
            }
            else {
                # Küçük boyutlar klasik DIB biçiminde; Windows Forms ile de uyumludur.
                $Writer = New-Object IO.BinaryWriter($Stream)
                $MaskStride = [int]([Math]::Ceiling($Size / 32) * 4)
                $Writer.Write([int]40); $Writer.Write([int]$Size); $Writer.Write([int]($Size * 2))
                $Writer.Write([uint16]1); $Writer.Write([uint16]32)
                $Writer.Write([int]0); $Writer.Write([int]($Size * $Size * 4))
                foreach ($Zero in 1..4) { $Writer.Write([int]0) }
                for ($Y = $Size - 1; $Y -ge 0; $Y--) {
                    for ($X = 0; $X -lt $Size; $X++) {
                        $Pixel = $Bitmap.GetPixel($X, $Y)
                        $Writer.Write([byte]$Pixel.B); $Writer.Write([byte]$Pixel.G)
                        $Writer.Write([byte]$Pixel.R); $Writer.Write([byte]$Pixel.A)
                    }
                }
                for ($Y = $Size - 1; $Y -ge 0; $Y--) {
                    $Mask = New-Object byte[] $MaskStride
                    for ($X = 0; $X -lt $Size; $X++) {
                        if ($Bitmap.GetPixel($X, $Y).A -lt 128) {
                            $Index = [int][Math]::Floor($X / 8)
                            $Mask[$Index] = $Mask[$Index] -bor (128 -shr ($X % 8))
                        }
                    }
                    $Writer.Write([byte[]]$Mask)
                }
                $Writer.Flush()
            }
            $Entries.Add(@{ Size = $Size; Bytes = $Stream.ToArray() })
        }
        finally {
            if ($null -ne $Graphics) { $Graphics.Dispose() }
            $Bitmap.Dispose(); $Stream.Dispose()
        }
    }
}
finally { $Source.Dispose() }
$File = [IO.File]::Create([IO.Path]::GetFullPath($OutputPath))
$Output = New-Object IO.BinaryWriter($File)
try {
    $Output.Write([uint16]0); $Output.Write([uint16]1); $Output.Write([uint16]$Entries.Count)
    $Offset = 6 + 16 * $Entries.Count
    foreach ($Entry in $Entries) {
        $Dimension = if ($Entry.Size -eq 256) { 0 } else { $Entry.Size }
        $Output.Write([byte]$Dimension); $Output.Write([byte]$Dimension)
        $Output.Write([byte]0); $Output.Write([byte]0)
        $Output.Write([uint16]1); $Output.Write([uint16]32)
        $Output.Write([int]$Entry.Bytes.Length); $Output.Write([int]$Offset)
        $Offset += $Entry.Bytes.Length
    }
    foreach ($Entry in $Entries) { $Output.Write([byte[]]$Entry.Bytes) }
}
finally { $Output.Dispose() }
Write-Output $OutputPath

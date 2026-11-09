param ([string]$Version = '1.0.0')
$ErrorActionPreference = 'Stop'
if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw 'Sürüm x.y.z biçiminde olmalı.' }
$Root = Split-Path $PSScriptRoot -Parent
$Output = Join-Path $Root 'release'
[IO.Directory]::CreateDirectory($Output) | Out-Null
$Stage = Join-Path $Output ('stage-' + [guid]::NewGuid())
try {
    $Product = Join-Path $Stage ('Insat-' + $Version)
    [IO.Directory]::CreateDirectory($Product) | Out-Null
    foreach ($Name in @('Kur.cmd', 'Baslat.cmd', 'insat.ps1', 'README.md', 'README.en.md', 'CHANGELOG.md', 'VERSION', 'app', 'data', 'assets')) {
        Copy-Item -LiteralPath (Join-Path $Root $Name) -Destination $Product -Recurse
    }
    $Archive = Join-Path $Output ('Insat-' + $Version + '-Windows.zip')
    Compress-Archive -LiteralPath $Product -DestinationPath $Archive -Force
    $Hash = (Get-FileHash -LiteralPath $Archive -Algorithm SHA256).Hash
    "$Hash  $([IO.Path]::GetFileName($Archive))" | Set-Content -LiteralPath ($Archive + '.sha256') -Encoding ASCII
    Write-Output $Archive
}
finally {
    if (Test-Path -LiteralPath $Stage) {
        # Yalnızca bu çalıştırmanın oluşturduğu, release altındaki tam hedefi temizle.
        $ResolvedStage = (Resolve-Path -LiteralPath $Stage).Path.TrimEnd('\')
        $ResolvedOutput = (Resolve-Path -LiteralPath $Output).Path.TrimEnd('\')
        if (-not $ResolvedStage.StartsWith($ResolvedOutput + '\', [StringComparison]::OrdinalIgnoreCase) -or
            (Split-Path $ResolvedStage -Leaf) -notmatch '^stage-[0-9a-fA-F-]{36}$') { throw 'Geçici paket klasörü hedefi doğrulanamadı.' }
        $Items = @((Get-Item -LiteralPath $ResolvedStage -Force)) + @(Get-ChildItem -LiteralPath $ResolvedStage -Recurse -Force)
        if (@($Items | Where-Object { ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 }).Count) { throw 'Geçici paket klasöründe bağlantı bulundu.' }
        for ($Attempt = 0; $Attempt -lt 4; $Attempt++) {
            try { Remove-Item -LiteralPath $ResolvedStage -Recurse -Force -ErrorAction Stop; break }
            catch [IO.IOException] { if ($Attempt -eq 3) { throw }; Start-Sleep -Milliseconds 500 }
        }
    }
}

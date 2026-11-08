#requires -Version 5.1
param(
    [switch]$SkipDownloads,
    [switch]$NoExecute,
    [string]$IsccPath = 'C:\Program Files (x86)\Inno Setup 6\ISCC.exe'
)

function Get-VendorInstallers {
    param([string]$VendorDir)
    if (-not (Test-Path $VendorDir)) { New-Item $VendorDir -ItemType Directory -Force | Out-Null }
    $downloads = @(
        @{ Url = 'https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe'; File = 'DockerDesktopInstaller.exe' },
        @{ Url = 'https://pkgs.tailscale.com/stable/tailscale-setup-full-latest.exe'; File = 'tailscale-setup.exe' }
    )
    foreach ($d in $downloads) {
        $dest = Join-Path $VendorDir $d.File
        if (Test-Path $dest) { Write-Host "Cached: $($d.File)"; continue }
        Write-Host "Downloading $($d.File)..."
        Invoke-WebRequest -Uri $d.Url -OutFile $dest -UseBasicParsing
    }
}

if (-not $NoExecute) {
    $ErrorActionPreference = 'Stop'
    $installerDir = $PSScriptRoot
    $repoRoot = Split-Path $installerDir
    if (-not $SkipDownloads) { Get-VendorInstallers -VendorDir (Join-Path $installerDir 'vendor') }
    . (Join-Path $installerDir 'lib\Stack.ps1')
    $stackDir = Join-Path $installerDir 'stack'
    if (Test-Path $stackDir) { Remove-Item $stackDir -Recurse -Force }
    $staleExe = Join-Path $installerDir 'output\SovereignERP-Setup.exe'
    if (Test-Path $staleExe) { Remove-Item $staleExe -Force }
    Copy-StackWithRename -SourceRoot $repoRoot -Destination $stackDir
    if (-not (Test-Path $IsccPath)) {
        throw "Inno Setup compiler not found at '$IsccPath'. Install Inno Setup 6 (winget install JRSoftware.InnoSetup) or pass -IsccPath."
    }
    & $IsccPath (Join-Path $installerDir 'setup.iss')
    if ($LASTEXITCODE -ne 0) { throw "Inno Setup compile failed (exit $LASTEXITCODE)." }
    $exe = Join-Path $installerDir 'output\SovereignERP-Setup.exe'
    if (-not (Test-Path $exe)) { throw "Expected output not found: $exe" }
    $size = [Math]::Round((Get-Item $exe).Length / 1MB, 1)
    Write-Host "BUILD OK: $exe ($size MB)"
}

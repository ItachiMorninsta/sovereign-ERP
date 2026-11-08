function Copy-StackWithRename {
    param(
        [string]$SourceRoot,
        [string]$Destination,
        [string]$OldPrefix = 'pizzawind-erp',
        [string]$NewPrefix = 'sovereign-ERP'
    )
    $composeSrc = Join-Path $SourceRoot 'docker-compose.yml'
    if (-not (Test-Path $composeSrc)) { throw "docker-compose.yml not found in $SourceRoot" }
    New-Item $Destination -ItemType Directory -Force | Out-Null
    (Get-Content $composeSrc -Raw).Replace($OldPrefix, $NewPrefix) |
        Set-Content (Join-Path $Destination 'docker-compose.yml') -Encoding UTF8
    foreach ($dir in @('config', 'addons')) {
        $from = Join-Path $SourceRoot $dir
        if (Test-Path $from) {
            Copy-Item $from (Join-Path $Destination $dir) -Recurse -Force
        }
    }
}

function New-RandomPassword {
    $chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
    $bytes = New-Object byte[] 24
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    -join ($bytes | ForEach-Object { $chars[$_ % $chars.Length] })
}

function New-SecretFiles {
    param([string]$InstallDir)
    if (-not (Test-Path $InstallDir)) { New-Item $InstallDir -ItemType Directory -Force | Out-Null }
    $pgPath = Join-Path $InstallDir 'odoo_pg_pass'
    $masterPath = Join-Path $InstallDir 'odoo_master_pass'
    if ((Test-Path $pgPath) -and (Test-Path $masterPath)) {
        return @{
            pgPass = (Get-Content $pgPath -Raw).Trim()
            masterPass = (Get-Content $masterPath -Raw).Trim()
        }
    }
    $pg = New-RandomPassword
    $master = New-RandomPassword
    Set-Content $pgPath $pg -NoNewline -Encoding ASCII
    Set-Content $masterPath $master -NoNewline -Encoding ASCII
    return @{ pgPass = $pg; masterPass = $master }
}

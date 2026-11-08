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

function Get-SecretStoreDirectory {
    # Canonical secret location. Lives under ProgramData (not the install dir) so
    # it survives an uninstall and a "keep data" re-install can reuse the same
    # passwords the persisted Postgres volume was initialised with.
    return (Join-Path $env:ProgramData 'SovereignERP')
}

function New-SecretFiles {
    param([string]$InstallDir)
    $store = Get-SecretStoreDirectory
    if (-not (Test-Path $store)) { New-Item $store -ItemType Directory -Force | Out-Null }
    $storePg = Join-Path $store 'odoo_pg_pass'
    $storeMaster = Join-Path $store 'odoo_master_pass'
    if ((Test-Path $storePg) -and (Test-Path $storeMaster)) {
        $pg = (Get-Content $storePg -Raw).Trim()
        $master = (Get-Content $storeMaster -Raw).Trim()
    } else {
        $pg = New-RandomPassword
        $master = New-RandomPassword
        Set-Content $storePg $pg -NoNewline -Encoding ASCII
        Set-Content $storeMaster $master -NoNewline -Encoding ASCII
    }
    # Mirror into the install dir so docker-compose `file: odoo_pg_pass`
    # (resolved relative to the compose directory) finds them.
    if ($InstallDir) {
        if (-not (Test-Path $InstallDir)) { New-Item $InstallDir -ItemType Directory -Force | Out-Null }
        Set-Content (Join-Path $InstallDir 'odoo_pg_pass') $pg -NoNewline -Encoding ASCII
        Set-Content (Join-Path $InstallDir 'odoo_master_pass') $master -NoNewline -Encoding ASCII
    }
    return @{ pgPass = $pg; masterPass = $master }
}

function Connect-TailscaleAccount {
    param([int]$TimeoutSeconds = 600)
    Write-Host 'Opening browser for Tailscale sign-in. Create or log into YOUR OWN free account.'
    Invoke-TailscaleCli -Arguments @('up') | Out-Null
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        $state = Get-TailscaleState
        if ($state.BackendState -eq 'Running') { return }
        Start-Sleep -Seconds 5
    }
    throw 'Tailscale sign-in was not completed. Finish the browser sign-in, then retry.'
}

function Enable-TailscaleFunnel {
    try {
        Invoke-TailscaleCli -Arguments @('funnel', '--bg', '8080') | Out-Null
    } catch {
        if ("$_" -match 'HTTPS') {
            Start-Process 'https://login.tailscale.com/admin/dns'
            throw 'Funnel needs HTTPS enabled on your Tailscale account. A browser page opened: enable "HTTPS Certificates", then press R to retry.'
        }
        throw
    }
}

function Get-TailscalePublicUrl {
    $state = Get-TailscaleState
    $dns = $state.Self.DNSName.TrimEnd('.')
    return "https://$dns"
}

function Test-PublicUrl {
    param([string]$Url)
    return ((Get-HttpStatus -Url $Url) -eq 200)
}

function Get-CardDirectory {
    return [Environment]::GetFolderPath('Desktop')
}

function Write-ConnectionCard {
    param([string]$InstallDir, [string]$PublicUrl, [string]$MasterPassword)
    $path = Join-Path (Get-CardDirectory) 'SovereignERP Connection Card.txt'
    @"
SOVEREIGN ERP - CONNECTION CARD
================================
Access from anywhere: $PublicUrl
Access in the shop:   http://localhost:8080
Odoo master password: $MasterPassword

Keep this file safe. The master password is required to create or
manage databases. First login: open the URL above and create your
company database using the master password.
"@ | Set-Content $path -Encoding UTF8
    return $path
}

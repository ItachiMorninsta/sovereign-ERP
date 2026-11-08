function Start-TailscaleLogin {
    # `tailscale up` prints the sign-in URL, then blocks until the browser auth
    # completes. Run it as a background job so we can read the URL while it waits.
    return (Start-Job -ScriptBlock { tailscale up 2>&1 })
}

function Read-TailscaleLoginOutput {
    param($Handle)
    if (-not $Handle) { return '' }
    return ((Receive-Job -Job $Handle -Keep -ErrorAction SilentlyContinue | Out-String))
}

function Stop-TailscaleLogin {
    param($Handle)
    if (-not $Handle) { return }
    Stop-Job -Job $Handle -ErrorAction SilentlyContinue
    Remove-Job -Job $Handle -Force -ErrorAction SilentlyContinue
}

function Select-TailscaleLoginUrl {
    param([string]$Text)
    if (-not $Text) { return $null }
    $m = [regex]::Match($Text, 'https://login\.tailscale\.com/\S+')
    if ($m.Success) { return $m.Value }
    return $null
}

function Connect-TailscaleAccount {
    param([int]$TimeoutSeconds = 600)
    Write-Host 'Opening browser for Tailscale sign-in. Create or log into YOUR OWN free account.'
    $job = Start-TailscaleLogin
    $urlShown = $false
    try {
        $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
        while ((Get-Date) -lt $deadline) {
            $state = Get-TailscaleState
            if ($state.BackendState -eq 'Running') { return }
            if (-not $urlShown) {
                $url = Select-TailscaleLoginUrl -Text (Read-TailscaleLoginOutput -Handle $job)
                if ($url) {
                    Write-Host "If a browser window did not open, sign in here: $url"
                    Start-Process $url
                    $urlShown = $true
                }
            }
            Start-Sleep -Seconds 5
        }
        throw 'Tailscale sign-in was not completed. Finish the browser sign-in, then retry.'
    } finally {
        Stop-TailscaleLogin -Handle $job
    }
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

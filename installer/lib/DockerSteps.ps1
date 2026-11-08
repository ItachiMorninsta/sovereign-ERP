function Wait-DockerEngine {
    param([int]$TimeoutSeconds = 300)
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        try { Invoke-DockerCli -Arguments @('info') | Out-Null; return }
        catch { Start-Sleep -Seconds 5 }
    }
    throw 'Docker engine did not start in time. Open Docker Desktop from the Start menu, wait until it says "Engine running", then retry.'
}

function Import-StackImages {
    param([string]$InstallDir)
    Write-Host 'Downloading ERP components (Odoo, PostgreSQL, Nginx)...'
    Invoke-WithRetry -Description 'Image download' -Attempts 3 -BaseDelaySeconds 5 -ScriptBlock {
        Invoke-DockerCli -Arguments @('compose', 'pull') -WorkingDir $InstallDir | Out-Null
    }
}

function Start-ErpStack {
    param([string]$InstallDir)
    Invoke-DockerCli -Arguments @('compose', 'up', '-d') -WorkingDir $InstallDir | Out-Null
}

function Wait-OdooReady {
    param([int]$TimeoutSeconds = 300)
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if ((Get-HttpStatus -Url 'http://localhost:8080') -eq 200) { return }
        Start-Sleep -Seconds 5
    }
    throw 'Odoo did not become ready in time. Check Docker Desktop is running, then retry.'
}

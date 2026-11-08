function Invoke-FirstRun {
    param([string]$InstallDir)
    $statePath = Join-Path $InstallDir 'data\state.json'
    $master = (Get-Content (Join-Path $InstallDir 'odoo_master_pass') -Raw).Trim()

    $steps = [ordered]@{
        WaitForDocker  = { Wait-DockerEngine }
        PullImages     = { Import-StackImages -InstallDir $InstallDir }
        StartStack     = { Start-ErpStack -InstallDir $InstallDir }
        WaitForOdoo    = { Wait-OdooReady }
        TailscaleLogin = { Connect-TailscaleAccount }
        EnableFunnel   = { Enable-TailscaleFunnel }
        VerifyUrl      = {
            $url = Get-TailscalePublicUrl
            if (-not (Test-PublicUrl -Url $url)) { throw "Public URL not reachable yet: $url" }
            $s = Get-InstallState -StatePath $statePath
            $s.publicUrl = $url
            Save-InstallState -StatePath $statePath -State $s
        }
        ConnectionCard = {
            $s = Get-InstallState -StatePath $statePath
            Write-ConnectionCard -InstallDir $InstallDir -PublicUrl $s.publicUrl -MasterPassword $master | Out-Null
        }
    }

    foreach ($name in $steps.Keys) {
        if (Test-StepComplete -StatePath $statePath -Step $name) {
            Write-Host "Skipping $name (already done)."
            continue
        }
        Write-Host "==> $name"
        while ($true) {
            try {
                & $steps[$name]
                Set-StepComplete -StatePath $statePath -Step $name
                break
            } catch {
                Write-Host "Step '$name' failed: $_" -ForegroundColor Red
                $choice = Read-Host 'Type R to retry, or X to exit'
                if ($choice -eq 'X') { throw 'Setup cancelled by user.' }
            }
        }
    }

    $s = Get-InstallState -StatePath $statePath
    Start-Process $s.publicUrl
    Write-Host 'Sovereign ERP is ready. Connection card saved to your desktop.' -ForegroundColor Green
}

function Invoke-DockerCli {
    param([string[]]$Arguments, [string]$WorkingDir)
    if ($WorkingDir) { Push-Location $WorkingDir }
    try { $out = & docker @Arguments 2>&1 }
    finally { if ($WorkingDir) { Pop-Location } }
    if ($LASTEXITCODE -ne 0) { throw (($out | Out-String).Trim()) }
    return $out
}

function Invoke-TailscaleCli {
    param([string[]]$Arguments)
    $out = & tailscale @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) { throw (($out | Out-String).Trim()) }
    return $out
}

function Get-HttpStatus {
    param([string]$Url)
    try {
        $r = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 15
        return [int]$r.StatusCode
    } catch { return 0 }
}

function Get-TailscaleState {
    $json = Invoke-TailscaleCli -Arguments @('status', '--json')
    return (($json | Out-String) | ConvertFrom-Json)
}

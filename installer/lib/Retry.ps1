function Invoke-WithRetry {
    param(
        [scriptblock]$ScriptBlock,
        [int]$Attempts = 3,
        [int]$BaseDelaySeconds = 2,
        [string]$Description = 'operation'
    )
    $lastError = $null
    for ($i = 0; $i -lt $Attempts; $i++) {
        try { return (& $ScriptBlock) }
        catch {
            $lastError = $_
            Write-Warning "$Description failed (attempt $($i + 1)/$Attempts): $_"
            if ($i -lt ($Attempts - 1) -and $BaseDelaySeconds -gt 0) {
                Start-Sleep -Seconds ($BaseDelaySeconds * [Math]::Pow(2, $i))
            }
        }
    }
    throw "$Description failed after $Attempts attempts. Last error: $lastError"
}

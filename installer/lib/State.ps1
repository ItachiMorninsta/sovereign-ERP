function Get-InstallState {
    param([string]$StatePath)
    $default = @{ completed = @(); publicUrl = $null }
    if (-not (Test-Path $StatePath)) { return $default }
    try {
        $raw = Get-Content $StatePath -Raw -ErrorAction Stop | ConvertFrom-Json
        $completed = @()
        if ($raw.completed) { $completed = @($raw.completed) }
        return @{ completed = $completed; publicUrl = $raw.publicUrl }
    } catch { return $default }
}

function Save-InstallState {
    param([string]$StatePath, [hashtable]$State)
    $dir = Split-Path $StatePath
    if (-not (Test-Path $dir)) { New-Item $dir -ItemType Directory -Force | Out-Null }
    @{ completed = @($State.completed); publicUrl = $State.publicUrl } |
        ConvertTo-Json -Depth 5 | Set-Content $StatePath -Encoding UTF8
}

function Set-StepComplete {
    param([string]$StatePath, [string]$Step)
    $s = Get-InstallState -StatePath $StatePath
    if (@($s.completed) -notcontains $Step) { $s.completed = @(@($s.completed) + $Step) }
    Save-InstallState -StatePath $StatePath -State $s
}

function Test-StepComplete {
    param([string]$StatePath, [string]$Step)
    $s = Get-InstallState -StatePath $StatePath
    return (@($s.completed) -contains $Step)
}

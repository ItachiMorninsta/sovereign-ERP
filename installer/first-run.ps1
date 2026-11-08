#requires -Version 5.1
param([string]$InstallDir = $PSScriptRoot)
foreach ($lib in @('State', 'Retry', 'External', 'DockerSteps', 'TailscaleSteps', 'Orchestrator')) {
    . (Join-Path $PSScriptRoot "lib\$lib.ps1")
}
Invoke-FirstRun -InstallDir $InstallDir

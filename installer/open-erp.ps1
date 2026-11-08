#requires -Version 5.1
param([string]$InstallDir = $PSScriptRoot)
. (Join-Path $InstallDir 'lib\State.ps1')
$state = Get-InstallState -StatePath (Join-Path $InstallDir 'data\state.json')
$url = if ($state.publicUrl) { $state.publicUrl } else { 'http://localhost:8080' }
Start-Process $url

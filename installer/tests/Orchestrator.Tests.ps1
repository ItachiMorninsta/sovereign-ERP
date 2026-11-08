BeforeAll {
    . "$PSScriptRoot\..\lib\State.ps1"
    . "$PSScriptRoot\..\lib\Retry.ps1"
    . "$PSScriptRoot\..\lib\External.ps1"
    . "$PSScriptRoot\..\lib\DockerSteps.ps1"
    . "$PSScriptRoot\..\lib\TailscaleSteps.ps1"
    . "$PSScriptRoot\..\lib\Orchestrator.ps1"
}

Describe 'Invoke-FirstRun' {
    BeforeEach {
        $script:dir = Join-Path ([IO.Path]::GetTempPath()) ("fr-test-" + [guid]::NewGuid())
        New-Item $script:dir -ItemType Directory -Force | Out-Null
        Set-Content (Join-Path $script:dir 'odoo_master_pass') 'masterpw' -NoNewline
        Mock Wait-DockerEngine {}
        Mock Import-StackImages {}
        Mock Start-ErpStack {}
        Mock Wait-OdooReady {}
        Mock Connect-TailscaleAccount {}
        Mock Enable-TailscaleFunnel {}
        Mock Get-TailscalePublicUrl { 'https://pc.ts.net' }
        Mock Test-PublicUrl { $true }
        Mock Write-ConnectionCard { 'card.txt' }
        Mock Start-Process {}
        Mock Write-Host {}
    }
    AfterEach { Remove-Item $script:dir -Recurse -Force -ErrorAction SilentlyContinue }

    It 'runs all steps in order and records completion' {
        Invoke-FirstRun -InstallDir $script:dir
        foreach ($step in @('WaitForDocker','PullImages','StartStack','WaitForOdoo','TailscaleLogin','EnableFunnel','VerifyUrl','ConnectionCard')) {
            Test-StepComplete -StatePath (Join-Path $script:dir 'data\state.json') -Step $step | Should -BeTrue
        }
        (Get-InstallState -StatePath (Join-Path $script:dir 'data\state.json')).publicUrl | Should -Be 'https://pc.ts.net'
        Should -Invoke Start-Process -Times 1 -ParameterFilter { $FilePath -eq 'https://pc.ts.net' }
    }
    It 'is idempotent: second run skips all steps' {
        Invoke-FirstRun -InstallDir $script:dir
        Invoke-FirstRun -InstallDir $script:dir
        Should -Invoke Import-StackImages -Times 1
    }
    It 'resumes from first incomplete step' {
        Set-StepComplete -StatePath (Join-Path $script:dir 'data\state.json') -Step 'WaitForDocker'
        Set-StepComplete -StatePath (Join-Path $script:dir 'data\state.json') -Step 'PullImages'
        Invoke-FirstRun -InstallDir $script:dir
        Should -Invoke Wait-DockerEngine -Times 0
        Should -Invoke Import-StackImages -Times 0
        Should -Invoke Start-ErpStack -Times 1
    }
    It 'retries a failed step when user types R' {
        $script:attempts = 0
        Mock Import-StackImages { $script:attempts++; if ($script:attempts -eq 1) { throw 'network' } }
        Mock Read-Host { 'R' }
        Invoke-FirstRun -InstallDir $script:dir
        $script:attempts | Should -Be 2
    }
    It 'exits when user types X' {
        Mock Import-StackImages { throw 'network' }
        Mock Read-Host { 'X' }
        { Invoke-FirstRun -InstallDir $script:dir } | Should -Throw '*cancelled*'
    }
    It 'fails VerifyUrl step when public URL unreachable' {
        Mock Test-PublicUrl { $false }
        Mock Read-Host { 'X' }
        { Invoke-FirstRun -InstallDir $script:dir } | Should -Throw
        Test-StepComplete -StatePath (Join-Path $script:dir 'data\state.json') -Step 'VerifyUrl' | Should -BeFalse
    }
}

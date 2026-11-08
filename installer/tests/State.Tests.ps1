BeforeAll { . "$PSScriptRoot\..\lib\State.ps1" }

Describe 'State helpers' {
    BeforeEach {
        $script:tmp = Join-Path ([IO.Path]::GetTempPath()) ("state-test-" + [guid]::NewGuid())
        $script:path = Join-Path $script:tmp 'data\state.json'
    }
    AfterEach { Remove-Item $script:tmp -Recurse -Force -ErrorAction SilentlyContinue }

    It 'returns default state when file missing' {
        $s = Get-InstallState -StatePath $script:path
        @($s.completed).Count | Should -Be 0
        $s.publicUrl | Should -BeNullOrEmpty
    }
    It 'returns default state when file corrupt' {
        New-Item (Split-Path $script:path) -ItemType Directory -Force | Out-Null
        Set-Content $script:path 'NOT JSON{{{'
        $s = Get-InstallState -StatePath $script:path
        @($s.completed).Count | Should -Be 0
    }
    It 'round-trips save and get' {
        Save-InstallState -StatePath $script:path -State @{ completed = @('A'); publicUrl = 'https://x.ts.net' }
        $s = Get-InstallState -StatePath $script:path
        $s.completed | Should -Contain 'A'
        $s.publicUrl | Should -Be 'https://x.ts.net'
    }
    It 'marks steps complete idempotently' {
        Set-StepComplete -StatePath $script:path -Step 'PullImages'
        Set-StepComplete -StatePath $script:path -Step 'PullImages'
        $s = Get-InstallState -StatePath $script:path
        @($s.completed).Count | Should -Be 1
        Test-StepComplete -StatePath $script:path -Step 'PullImages' | Should -BeTrue
        Test-StepComplete -StatePath $script:path -Step 'Nope' | Should -BeFalse
    }
}

Describe 'Test harness' {
    It 'runs Pester 5' {
        (Get-Module Pester).Version.Major | Should -BeGreaterOrEqual 5
    }
}

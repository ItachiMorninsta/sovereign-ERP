BeforeAll { . "$PSScriptRoot\..\lib\Retry.ps1" }

Describe 'Invoke-WithRetry' {
    It 'returns result on first success' {
        Invoke-WithRetry -ScriptBlock { 42 } -Attempts 3 -BaseDelaySeconds 0 -Description 'test' | Should -Be 42
    }
    It 'retries until success' {
        $script:calls = 0
        $result = Invoke-WithRetry -Attempts 3 -BaseDelaySeconds 0 -Description 'flaky' -ScriptBlock {
            $script:calls++
            if ($script:calls -lt 3) { throw 'transient' }
            'ok'
        }
        $result | Should -Be 'ok'
        $script:calls | Should -Be 3
    }
    It 'throws after exhausting attempts' {
        { Invoke-WithRetry -Attempts 2 -BaseDelaySeconds 0 -Description 'always fails' -ScriptBlock { throw 'boom' } } |
            Should -Throw '*always fails*'
    }
}

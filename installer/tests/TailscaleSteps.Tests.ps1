BeforeAll {
    . "$PSScriptRoot\..\lib\External.ps1"
    . "$PSScriptRoot\..\lib\TailscaleSteps.ps1"
}

Describe 'Tailscale steps' {
    BeforeEach { Mock Start-Sleep {} }

    It 'Connect-TailscaleAccount polls until Running and surfaces the sign-in URL' {
        Mock Start-TailscaleLogin { 'job-handle' }
        Mock Read-TailscaleLoginOutput { 'To sign in, visit https://login.tailscale.com/a/abc123' }
        Mock Stop-TailscaleLogin {}
        Mock Start-Process {}
        $script:polls = 0
        Mock Get-TailscaleState {
            $script:polls++
            if ($script:polls -lt 2) { [pscustomobject]@{ BackendState = 'NeedsLogin' } }
            else { [pscustomobject]@{ BackendState = 'Running' } }
        }
        { Connect-TailscaleAccount -TimeoutSeconds 60 } | Should -Not -Throw
        Should -Invoke Start-TailscaleLogin -Times 1
        Should -Invoke Start-Process -Times 1 -ParameterFilter { $FilePath -eq 'https://login.tailscale.com/a/abc123' }
        Should -Invoke Stop-TailscaleLogin -Times 1
    }
    It 'Connect-TailscaleAccount throws on timeout and still cleans up the job' {
        Mock Start-TailscaleLogin { 'job-handle' }
        Mock Read-TailscaleLoginOutput { '' }
        Mock Stop-TailscaleLogin {}
        Mock Get-TailscaleState { [pscustomobject]@{ BackendState = 'NeedsLogin' } }
        { Connect-TailscaleAccount -TimeoutSeconds 1 } | Should -Throw '*sign-in*'
        Should -Invoke Stop-TailscaleLogin -Times 1
    }
    It 'Select-TailscaleLoginUrl extracts the auth URL and returns nothing when absent' {
        Select-TailscaleLoginUrl -Text 'visit https://login.tailscale.com/a/xyz now' | Should -Be 'https://login.tailscale.com/a/xyz'
        Select-TailscaleLoginUrl -Text 'no url here' | Should -BeNullOrEmpty
    }
    It 'Enable-TailscaleFunnel runs funnel --bg 8080' {
        Mock Invoke-TailscaleCli { 'funnel on' }
        Enable-TailscaleFunnel
        Should -Invoke Invoke-TailscaleCli -Times 1 -ParameterFilter { ($Arguments -join ' ') -eq 'funnel --bg 8080' }
    }
    It 'Enable-TailscaleFunnel opens admin page on HTTPS error' {
        Mock Invoke-TailscaleCli { throw 'HTTPS must be enabled on your tailnet to use funnel' }
        Mock Start-Process {}
        { Enable-TailscaleFunnel } | Should -Throw '*HTTPS*'
        Should -Invoke Start-Process -Times 1 -ParameterFilter { $FilePath -eq 'https://login.tailscale.com/admin/dns' }
    }
    It 'Get-TailscalePublicUrl trims trailing dot' {
        Mock Get-TailscaleState { [pscustomobject]@{ Self = [pscustomobject]@{ DNSName = 'pc.tail1234.ts.net.' } } }
        Get-TailscalePublicUrl | Should -Be 'https://pc.tail1234.ts.net'
    }
    It 'Test-PublicUrl reflects HTTP status' {
        Mock Get-HttpStatus { 200 }
        Test-PublicUrl -Url 'https://x.ts.net' | Should -BeTrue
        Mock Get-HttpStatus { 0 }
        Test-PublicUrl -Url 'https://x.ts.net' | Should -BeFalse
    }
}

Describe 'Write-ConnectionCard' {
    It 'writes card with URL and master password' {
        $tmp = Join-Path ([IO.Path]::GetTempPath()) ("card-test-" + [guid]::NewGuid())
        New-Item $tmp -ItemType Directory -Force | Out-Null
        Mock Start-Process {}
        Mock Get-CardDirectory { $tmp }
        $path = Write-ConnectionCard -InstallDir $tmp -PublicUrl 'https://pc.ts.net' -MasterPassword 'secret123'
        Test-Path $path | Should -BeTrue
        $body = Get-Content $path -Raw
        $body | Should -Match 'https://pc\.ts\.net'
        $body | Should -Match 'secret123'
        $body | Should -Match 'http://localhost:8080'
        Remove-Item $tmp -Recurse -Force
    }
}

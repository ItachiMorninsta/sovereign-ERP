BeforeAll {
    . "$PSScriptRoot\..\lib\Retry.ps1"
    . "$PSScriptRoot\..\lib\External.ps1"
    . "$PSScriptRoot\..\lib\DockerSteps.ps1"
}

Describe 'Docker steps' {
    BeforeEach { Mock Start-Sleep {} }

    It 'Wait-DockerEngine returns once engine responds' {
        $script:n = 0
        Mock Invoke-DockerCli {
            $script:n++
            if ($script:n -lt 3) { throw 'engine down' }
            'ok'
        }
        { Wait-DockerEngine -TimeoutSeconds 60 } | Should -Not -Throw
        $script:n | Should -Be 3
    }
    It 'Wait-DockerEngine throws actionable error on timeout' {
        Mock Invoke-DockerCli { throw 'engine down' }
        { Wait-DockerEngine -TimeoutSeconds 1 } | Should -Throw '*Docker Desktop*'
    }
    It 'Import-StackImages runs compose pull in install dir' {
        Mock Invoke-DockerCli { 'pulled' }
        Import-StackImages -InstallDir 'C:\SovereignERP'
        Should -Invoke Invoke-DockerCli -Times 1 -ParameterFilter {
            ($Arguments -join ' ') -eq 'compose pull' -and $WorkingDir -eq 'C:\SovereignERP'
        }
    }
    It 'Start-ErpStack runs compose up -d' {
        Mock Invoke-DockerCli { 'started' }
        Start-ErpStack -InstallDir 'C:\SovereignERP'
        Should -Invoke Invoke-DockerCli -Times 1 -ParameterFilter {
            ($Arguments -join ' ') -eq 'compose up -d'
        }
    }
    It 'Wait-OdooReady returns on HTTP 200' {
        $script:h = 0
        Mock Get-HttpStatus { $script:h++; if ($script:h -lt 2) { 0 } else { 200 } }
        { Wait-OdooReady -TimeoutSeconds 60 } | Should -Not -Throw
    }
    It 'Wait-OdooReady throws on timeout' {
        Mock Get-HttpStatus { 0 }
        { Wait-OdooReady -TimeoutSeconds 1 } | Should -Throw '*Odoo*'
    }
}

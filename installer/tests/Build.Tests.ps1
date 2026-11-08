BeforeAll {
    . "$PSScriptRoot\..\lib\Stack.ps1"
    . "$PSScriptRoot\..\build.ps1" -NoExecute
}

Describe 'Get-VendorInstallers' {
    BeforeEach {
        $script:vendor = Join-Path ([IO.Path]::GetTempPath()) ("vendor-test-" + [guid]::NewGuid())
        New-Item $script:vendor -ItemType Directory -Force | Out-Null
        Mock Invoke-WebRequest {}
    }
    AfterEach { Remove-Item $script:vendor -Recurse -Force -ErrorAction SilentlyContinue }

    It 'downloads both installers' {
        Get-VendorInstallers -VendorDir $script:vendor
        Should -Invoke Invoke-WebRequest -Times 2
    }
    It 'skips files that already exist' {
        Set-Content (Join-Path $script:vendor 'DockerDesktopInstaller.exe') 'cached'
        Set-Content (Join-Path $script:vendor 'tailscale-setup.exe') 'cached'
        Get-VendorInstallers -VendorDir $script:vendor
        Should -Invoke Invoke-WebRequest -Times 0
    }
}

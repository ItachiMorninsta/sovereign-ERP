BeforeAll { . "$PSScriptRoot\..\lib\Stack.ps1" }

Describe 'Copy-StackWithRename' {
    BeforeEach {
        $script:root = Join-Path ([IO.Path]::GetTempPath()) ("stack-test-" + [guid]::NewGuid())
        $script:src = Join-Path $script:root 'src'
        $script:dst = Join-Path $script:root 'dst'
        New-Item "$script:src\config" -ItemType Directory -Force | Out-Null
        New-Item "$script:src\addons\demo" -ItemType Directory -Force | Out-Null
        Set-Content "$script:src\docker-compose.yml" "volumes:`n  odoo-db-data:`n    name: pizzawind-erp_odoo-db-data"
        Set-Content "$script:src\config\odoo.conf" '[options]'
        Set-Content "$script:src\addons\demo\__manifest__.py" '{}'
    }
    AfterEach { Remove-Item $script:root -Recurse -Force -ErrorAction SilentlyContinue }

    It 'copies stack and renames volume prefix' {
        Copy-StackWithRename -SourceRoot $script:src -Destination $script:dst
        $compose = Get-Content "$script:dst\docker-compose.yml" -Raw
        $compose | Should -Match 'sovereign-ERP_odoo-db-data'
        $compose | Should -Not -Match 'pizzawind-erp'
        Test-Path "$script:dst\config\odoo.conf" | Should -BeTrue
        Test-Path "$script:dst\addons\demo\__manifest__.py" | Should -BeTrue
    }
    It 'throws when compose file missing' {
        Remove-Item "$script:src\docker-compose.yml"
        { Copy-StackWithRename -SourceRoot $script:src -Destination $script:dst } | Should -Throw
    }
}

Describe 'New-SecretFiles' {
    BeforeEach {
        $script:dir = Join-Path ([IO.Path]::GetTempPath()) ("secret-test-" + [guid]::NewGuid())
        $script:store = Join-Path ([IO.Path]::GetTempPath()) ("secret-store-" + [guid]::NewGuid())
        New-Item $script:dir -ItemType Directory -Force | Out-Null
        Mock Get-SecretStoreDirectory { $script:store }
    }
    AfterEach {
        Remove-Item $script:dir -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item $script:store -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'creates two distinct 24-char passwords in the store and mirrors them to the install dir' {
        $r = New-SecretFiles -InstallDir $script:dir
        $r.pgPass.Length | Should -Be 24
        $r.masterPass.Length | Should -Be 24
        $r.pgPass | Should -Not -Be $r.masterPass
        $r.pgPass | Should -Match '^[A-Za-z0-9]{24}$'
        (Get-Content "$script:store\odoo_pg_pass" -Raw).Trim() | Should -Be $r.pgPass
        (Get-Content "$script:store\odoo_master_pass" -Raw).Trim() | Should -Be $r.masterPass
        (Get-Content "$script:dir\odoo_pg_pass" -Raw).Trim() | Should -Be $r.pgPass
        (Get-Content "$script:dir\odoo_master_pass" -Raw).Trim() | Should -Be $r.masterPass
    }
    It 'does not overwrite existing secrets' {
        $first = New-SecretFiles -InstallDir $script:dir
        $second = New-SecretFiles -InstallDir $script:dir
        $second.pgPass | Should -Be $first.pgPass
        $second.masterPass | Should -Be $first.masterPass
    }
    It 'reuses canonical secrets for a fresh install dir (re-install after keep-data uninstall)' {
        $first = New-SecretFiles -InstallDir $script:dir
        $newDir = Join-Path ([IO.Path]::GetTempPath()) ("secret-reinstall-" + [guid]::NewGuid())
        try {
            $second = New-SecretFiles -InstallDir $newDir
            $second.pgPass | Should -Be $first.pgPass
            $second.masterPass | Should -Be $first.masterPass
            (Get-Content "$newDir\odoo_master_pass" -Raw).Trim() | Should -Be $first.masterPass
        } finally {
            Remove-Item $newDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

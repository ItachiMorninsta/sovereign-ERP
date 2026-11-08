# sovereign-ERP

Self-hosted Odoo 18 ERP for small businesses: one Windows Setup.exe installs
everything (Docker Desktop, Tailscale, Odoo/PostgreSQL/Nginx stack) and gives
the business a public https URL with no domain purchase. Data persists in
Docker volumes; the stack auto-starts after a user signs in to Windows
(Docker Desktop's engine starts at login, not at power-on before login).

## Stack (source)
`docker-compose.yml` + `config/` + `addons/` — Odoo 18.0, PostgreSQL 15,
Nginx on port 8080. The original deployment for the pizzeria client keeps
its `pizzawind-erp_*` volume names; the packaged product rewrites them to
`sovereign-ERP_*` at build time.

## Build the installer (maintainer)
Requirements: Windows, PowerShell 5.1, Inno Setup 6
(`winget install --id JRSoftware.InnoSetup -e`), Pester 5 for tests
(`Install-Module Pester -Scope CurrentUser -Force`), internet.

    powershell -ExecutionPolicy Bypass -File installer\build.ps1

Output: `installer\output\SovereignERP-Setup.exe` (~700 MB). First build
downloads Docker Desktop + Tailscale installers into `installer\vendor\`
(cached afterwards). Run tests:

    powershell -ExecutionPolicy Bypass -File installer\tests\run-tests.ps1

## Install at a client site
1. Copy SovereignERP-Setup.exe to the client PC (Windows 10/11, admin,
   internet). Double-click, follow the wizard, accept the reboot.
2. After reboot, setup continues automatically. The client signs into THEIR
   OWN free Tailscale account in the browser when prompted.
3. Setup ends with the public URL open and a connection card on the desktop.
   The client creates their company database using the master password on
   the card. Full acceptance checklist: `installer/CLEAN-VM-TEST.md`.

## Licensing note
Docker Desktop is free for personal use and small businesses (<250 employees
AND <$10M annual revenue). Verify each client qualifies; otherwise a Docker
subscription is required.

## Uninstall
Settings > Apps > Sovereign ERP. You are asked whether to delete business
data (default: keep).

- **Keep data (No):** the Docker volumes and the ERP passwords (stored in
  `C:\ProgramData\SovereignERP`) are left in place. A later re-install reuses
  them, so the same databases come back with the same master password.
- **Delete data (Yes):** the stack is taken down, the `sovereign-ERP_*`
  volumes are removed, and the `C:\ProgramData\SovereignERP` passwords are
  wiped — a fully clean slate.

Docker Desktop and Tailscale are **not** removed by the uninstaller; they are
shared dependencies and removing them automatically is slow and can disrupt
other software. Remove them yourself via Settings > Apps if the machine no
longer needs them.

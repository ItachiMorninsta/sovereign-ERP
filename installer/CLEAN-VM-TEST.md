# Clean-VM Acceptance Test (~30 minutes)

Prerequisites: fresh Windows 10/11 x64 VM (Hyper-V or VirtualBox), 8 GB+ RAM,
20 GB+ disk, internet, NO Docker/Tailscale/WSL preinstalled. Take a snapshot
before starting so you can re-run from clean.

## End-to-end
1. Copy SovereignERP-Setup.exe into the VM. Double-click. Accept elevation.
2. Wizard completes; accept the restart prompt when offered.
3. After login, first-run window continues automatically (RunOnce).
4. Complete the Tailscale browser sign-in with a fresh account.
5. If prompted about HTTPS: enable HTTPS Certificates in the opened admin
   page, press R in the first-run window.
6. Verify: browser opens the public https URL and shows the Odoo database
   creation screen; connection card exists on the desktop with URL + master
   password; `docker ps` in the VM shows 3 running containers.
7. From a DIFFERENT device/network (e.g., your phone on mobile data), open
   the public URL — Odoo login page must load.
8. Create a test database with the master password; confirm login works.

## Reboot persistence
9. Reboot the VM. Do NOT run anything manually. Within ~3 minutes the public
   URL must respond again (Docker autostart + restart:always + funnel persist).

## Failure paths (use snapshots to reset between these)
10. Kill VM internet during image pull → first-run shows retry; restore
    internet, press R → completes.
11. Abandon the Tailscale browser login → clear sign-in error with R/X prompt.
12. Run first-run.ps1 a second time after success → all steps skipped, no
    errors, nothing duplicated.

## Uninstall / re-install
13. Uninstall via Settings > Apps. Choose "No" at the delete-data prompt.
    Verify `docker volume ls` still shows sovereign-ERP volumes.
14. Re-install → existing data volumes reused (test database still present).
15. Uninstall again, choose "Yes" → volumes removed.

Record pass/fail per item; report failures with the first-run log output.

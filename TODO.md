# TODO: Project Task Tracking

---

# NEXT: Frontend Integration for Execution Modules

Wire UpdateExecutor and PackageExecutor into the Sinatra API and React dashboard.

- [ ] Add `POST /api/assets/:name/updates/install` endpoint (Windows)
- [ ] Add `POST /api/assets/:name/packages/upgrade` endpoint (Linux)
- [ ] Add `GET /api/assets/:name/reboot-status` endpoint
- [ ] Add `POST /api/assets/:name/reboot` endpoint
- [ ] Frontend controls: install/upgrade buttons, reboot prompts, progress display
- [ ] Goal: all backend functionality accessible from the dashboard

---

# Completed

## Linux Package Execution Module (2026-02-10)
- `PatchPilot::Linux::PackageExecutor` factory with `AptExecutor` and `DnfExecutor` implementations
- `upgrade_all`, `upgrade_packages(packages:)`, `reboot_required?`
- APT: `DEBIAN_FRONTEND=noninteractive apt-get upgrade -y`, reboot check via `/var/run/reboot-required`
- DNF: `dnf upgrade -y`, reboot check via `needs-restarting -r` with availability guard
- Parses upgraded package names and counts from command output
- 246 RSpec tests passing, RuboCop clean

## Windows Update Execution Module (2026-02-10)
- `PatchPilot::Windows::UpdateExecutor` — search, download, and install updates via COM API over WinRM
- Three structs: `AvailableUpdate`, `UpdateActionResult`, `InstallationResult`
- KB filtering, reboot detection (registry checks), explicit reboot trigger
- Reboot never automatic — critical for Deep Freeze endpoints
- 208 RSpec tests passing, RuboCop clean

## Connectivity Fixes (2026-02-02)
- Fixed missing `password` fields in `config/inventory.yml` credentials (WinRM and SSH)
- Fixed incorrect PC endpoint IPs (`172.29.70.x` → `172.29.10.x`)
- Fixed SSH `auth_options` to check key file existence before using `keys_only: true`, enabling password fallback
- Added `Socket.tcp` port pre-check to WinRM connect for fast failure with clear error messages
- Added thread-based 10s timeout around WinRM negotiate (gem's built-in timeouts are unreliable)
- Fixed stale hostnames in `inventory_spec.rb` and `bin/test_connections`
- Refactored `bin/test_connections` for RuboCop compliance
- 155 RSpec tests passing, RuboCop clean

## Dashboard Bugfixes (2026-01-27)
- Fixed false online status: status endpoint now executes `echo test` command
- Added `dotenv` gem for `.env` loading
- Fixed GSAP animation stalling with `requestAnimationFrame` + `fromTo`
- Fixed PC1 domain trust with `Test-ComputerSecureChannel -Repair`

## Web Dashboard MVP (2026-01-26)
- Sinatra API (`api/server.rb`) + Vite/React/TypeScript frontend (`web-gui/`)
- Asset cards, detail modals, compare view, Deep Freeze analysis
- Dark mode DaisyUI theme, GSAP animations

## Linux Package Query Module (2026-01-26)
- `PatchPilot::Linux::PackageQuery` factory with `AptQuery` and `DnfQuery` implementations
- Installed packages, upgradable packages, filtering, comparison

## Windows Update Query Module (2026-01-26)
- `PatchPilot::Windows::UpdateQuery` — queries `Get-HotFix`, parses into `Update` structs
- Filtering by date range and KB pattern, comparison helper for Deep Freeze verification

## Remote Execution Layer (2026-01-24)
- `PatchPilot::Connections::WinRM` and `PatchPilot::Connections::SSH`
- `PatchPilot::CredentialResolver` for `${VAR}` environment variable expansion

## Asset Inventory
- `PatchPilot::Inventory` loads `config/inventory.yml`
- Filtering: `windows`, `linux`, `deep_freeze_enabled`, `control_endpoints`, `docker_hosts`, `by_tag`, `by_role`

# TODO: Project Task Tracking

---

# NEXT: Windows Update Execution Module

Trigger Windows Update installation remotely via PowerShell.

**Prerequisite**: Lab environment with Windows systems running and accessible via WinRM.

- [ ] Create `PatchPilot::Windows::UpdateExecutor` class
- [ ] Implement Windows Update installation via PowerShell
- [ ] Handle reboot requirements
- [ ] Add progress tracking/status reporting
- [ ] Write tests with mocked WinRM responses

---

# NEXT: Linux Package Execution Module

Trigger package updates remotely via SSH. Supports APT (Ubuntu, Kali) and DNF (Fedora).

- [ ] Create `PatchPilot::Linux::PackageExecutor` class
- [ ] Implement `apt upgrade` / `dnf upgrade` execution
- [ ] Handle confirmation prompts
- [ ] Add progress tracking/status reporting
- [ ] Write tests with mocked SSH responses

---

# Completed

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

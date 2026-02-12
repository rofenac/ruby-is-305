# TODO: Project Task Tracking

---

# NEXT: Verify available updates + reboot guard end-to-end

Test via the dashboard:
1. Available updates fix on Windows endpoints (timeout + SYSTEM task wrapper)
2. Reboot pending guard — DC1 (pending reboot) should show "Reboot to finalize" instead of install button

## Backlog
- End-to-end integration testing against lab environment
- Scheduled/automated patch runs
- Reporting and history tracking
- Add update `title` field from COM API to installed updates display

---

# Completed

## Reboot Pending Guard (2026-02-12)
- `GET /api/assets/:name/updates/available` now includes `reboot_pending` boolean (uses same connection, no extra overhead)
- `POST /api/assets/:name/updates/install` returns 409 if reboot is pending (safety net)
- `POST /api/assets/:name/packages/upgrade` returns 409 if reboot is pending (Linux parity)
- Frontend: replaces "Install All Updates" button with "Reboot to finalize" warning when `reboot_pending` is true
- Also triggers reboot status section visibility via `onRebootRequired()` callback
- 297 RSpec tests passing, RuboCop clean, frontend builds clean

## Available Updates Fix — Timeouts + SYSTEM Task Wrapper (2026-02-12)
- **Root cause 1**: WinRM `receive_timeout` (10s) was shorter than `operation_timeout` (30s) — HTTP client killed connections before the server could respond. Any command >10s failed silently returning empty. Fixed: `operation_timeout` now configurable (default 60s), `receive_timeout` always set to `operation_timeout + 10`.
- **Root cause 2**: WinRM "network" logon token gets `E_ACCESSDENIED` (0x80070005) from WU COM API `Search()` when there are actual pending updates. Fixed: `available_updates` now uses the same scheduled task wrapper as install — runs the search as SYSTEM with full privileges.
- Refactored `build_task_wrapper` to accept `task_name:` keyword — reusable for both `Search` and `Install` operations with separate temp file paths
- Added `detect_search_error!` to surface inner script errors from the task wrapper result JSON
- Manual RDP test confirmed the search works interactively (12 seconds, 3 updates found on PC3)
- 293 RSpec tests passing, RuboCop clean

## Linux sudo + Windows Query/Executor Fixes (2026-02-11)
- Linux executors: added `sudo` prefix to all upgrade commands (apt-get, dnf)
- Windows UpdateQuery: combined `Get-HotFix` (CBS baseline) + `QueryHistory()` (WUA supplement) for complete installed update coverage
- Windows UpdateExecutor: added `ServerSelection = 2` to all COM API searchers — forces Windows Update online, bypassing WSUS Group Policy on domain-joined machines
- JSON output replaces CSV parsing; `description` derived from update categories
- 288 RSpec tests passing, RuboCop clean

## Windows/Linux Execution Layers (2026-02-11)
- 5 new API endpoints: available updates, install updates, upgrade packages, reboot status, reboot
- `GET /api/assets/:name/updates/available` — Windows available update search via COM API
- `POST /api/assets/:name/updates/install` — install Windows updates (all or specific KBs)
- `POST /api/assets/:name/packages/upgrade` — upgrade Linux packages (all or specific)
- `GET /api/assets/:name/reboot-status` — check reboot pending (Windows + Linux)
- `POST /api/assets/:name/reboot` — trigger reboot with connection-drop handling
- React dashboard: check available updates, install/upgrade with confirmation, progress display
- Deep Freeze guard: 409 on install/reboot for `deep_freeze: true` assets; frontend hides execution UI
- Scheduled task wrapper for Windows Update install (WinRM non-interactive sessions can't call `IUpdateInstaller.Install`)
- Reboot status section with explicit reboot trigger
- 286 RSpec tests passing, RuboCop clean, frontend builds clean

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

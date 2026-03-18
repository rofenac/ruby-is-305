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
- Add update `title` field to the installed updates table in the asset detail modal (API already captures it via `Update#title`; `update_to_hash` in `lib/patch_pilot/serializers.rb` does not yet expose it)
- **SB4 intermittent comms loss** (recurring): host drops mid-session. `session.loop` blocks indefinitely when a host goes unresponsive — need a configurable per-credential command timeout so hung sessions fail cleanly instead of hanging forever.
- **SB3 partial upgrade stall** (recurring): installs most packages but consistently stops with ~10 remaining. Retrying the upgrade fails (likely a lock file or partial dpkg state). Need to investigate root cause — possibly a post-install script hanging, a held package, or a dpkg lock not being released. A timeout on `session.loop` (see above) would also help surface this failure cleanly.

---

# Completed

## Refactor + Auth Fix (2026-03-18)
- **Browser auth dialog suppressed**: removed `WWW-Authenticate: Basic` header from 401 responses — browser no longer shows its native credential modal; custom login page handles all auth UI
- **`download_updates` timeout fix**: was calling WinRM directly, now runs through the scheduled task wrapper (same as install) — large downloads no longer time out the WinRM session
- **Dead code removed**: `action_script` install branch and `install_powershell_block` in `UpdateExecutor` were unreachable; removed
- **`normalize_kb` deduplication**: extracted to `lib/patch_pilot/windows/kb_helpers.rb` (`KbHelpers` module), included by both `UpdateQuery` and `UpdateExecutor`
- **Serializers extracted**: all `*_to_hash` and response-builder helpers moved to `lib/patch_pilot/serializers.rb` (`PatchPilot::Serializers`); server.rb helpers block reduced to Sinatra-coupled concerns only
- **`client.ts` simplified**: `fetchJson` + `postJson` merged into a single `apiFetch<T>(url, init?)` function
- **`compare_with` refactored**: extracted `security_update_index` + `sorted_entries` helpers to bring method within RuboCop Metrics limits
- Pre-existing spec failures fixed: inventory endpoint counts, `compare_with` hash format assertions, `WWW-Authenticate` header assertion
- 310 RSpec tests passing, RuboCop clean, TypeScript clean

## Compare View: Security Updates + Icon Consistency (2026-03-16)
- `UpdateQuery#compare_with` now filters to **security updates only** (via `security_update?`) and returns `{ kb:, title: }` hashes instead of plain KB number strings
- PowerShell query script restructured: WU history (`QueryHistory`) runs first to capture full update titles (e.g. `2026-03 Cumulative Update for Windows 10 (KB5079473)`); `Get-HotFix` runs as fallback for anything not in history. Fixed broken KB extraction regex (`\(KB(\d+)\)` was incorrectly escaped in the original).
- `Update` struct gains `:title` field; `build_update` populates it from `$Entry.Title` (WU history) or constructs `"Security Update (KB...)"` from HotFix fallback
- `ComparisonResponse` TypeScript type split into discriminated union: `WindowsComparisonResponse` (entries are `SecurityUpdateEntry[]`) vs `LinuxComparisonResponse` (entries are `string[]`)
- Compare page: full update names shown in results lists, header says "Security Update Comparison", Deep Freeze analysis section explicitly confirms whether DFE is applying patches
- Icon consistency: `AssetDetail` modal header and `CompareView` selection cards now use `OsIcon` / `WindowsIcon` / `LinuxIcon` from `osIcon.tsx` instead of plain `🪟`/`🐧` emojis

## Frontend Login Page + Logout (2026-03-16)
- `GET /api/auth/verify` endpoint added to backend (protected by existing basic auth)
- `client.ts`: credentials stored as `Basic <base64>` in `sessionStorage`; all fetch/post calls include `Authorization` header; 401 throws `'Unauthorized'`
- `LoginPage.tsx`: centered card with username/password form, GSAP slide-in, error state on bad creds
- `Navbar.tsx`: Sign Out button (arrow icon, red on hover) added to navbar-end
- `App.tsx`: `isAuthenticated` state gates entire app; tab refresh doesn't require re-login; any API 401 auto-logs out
- Credentials still configured via `PATCHPILOT_AUTH_USERNAME` / `PATCHPILOT_AUTH_PASSWORD` in docker-compose

## Dashboard Subsections + Brand Icons (2026-03-16)
- `asset_to_hash` now exposes `os_version`, `role`, and `tags` in the inventory API response
- `Asset` TypeScript interface updated with `os_version`, `role`, `tags` fields
- Dashboard restructured: "Windows Systems" replaced with separate **Windows Servers** and **Windows Workstations** top-level sections
- Windows Servers subsections: Domain Controllers (👑), Member Servers (🗄️)
- Windows Workstations subsections: Teacher's Workstation (🎓), Lab Workstations (💻), Hot Spares (🔥), NMWSes (📡)
- `inventory.yml`: t215-25 → `role: teacher_workstation`; t215-26/27/28 → `role: hot_spare`
- Installed `react-icons`; created `src/utils/osIcon.tsx` as single source of truth for OS → icon + color mapping
- Classic 4-color Windows flag SVG (inline, no dependency) replaces 🪟 everywhere
- Linux distro icons with brand colors: RHEL (`#EE0000`), Kali (`#367BF0`), Fedora (`#51A2DA`), Ubuntu (`#E95420`), Docker (`#2496ED`), generic Linux (`#FCC624`)
- GSAP stagger continuity preserved across subsections via pre-computed index offsets

# Completed (prior)

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

# TODO: Project Task Tracking

---

# NEXT: Windows Update Execution Module

## Overview

Trigger Windows Update installation remotely via PowerShell. This enables orchestrated patch deployment across the environment.

**Prerequisite**: Lab environment with Windows systems running and accessible via WinRM.

## Implementation Tasks

- [ ] Create `PatchPilot::Windows::UpdateExecutor` class
- [ ] Implement Windows Update installation via PowerShell
- [ ] Handle reboot requirements
- [ ] Add progress tracking/status reporting
- [ ] Write tests with mocked WinRM responses

---

# NEXT: Linux Package Execution Module

## Overview

Trigger package updates remotely via SSH. Supports APT (Ubuntu, Kali) and DNF (Fedora).

## Implementation Tasks

- [ ] Create `PatchPilot::Linux::PackageExecutor` class
- [ ] Implement `apt upgrade` / `dnf upgrade` execution
- [ ] Handle confirmation prompts
- [ ] Add progress tracking/status reporting
- [ ] Write tests with mocked SSH responses

---

# COMPLETED: Dashboard Status Check and Animation Fixes (2026-01-27)

## Overview

Critical bugfixes for the web dashboard to ensure accurate connectivity status and smooth GSAP animations.

## Issues Fixed

### 1. False Online Status
**Problem**: Dashboard showed all assets as "online" even when powered off.

**Root Cause**:
- Status endpoint created connection objects but never tested them
- Missing environment variable loading from `.env` file
- No connection timeouts configured

**Solution**:
- Added `dotenv` gem to load `.env` file automatically
- Modified `/api/assets/:name/status` to execute `echo test` command
- Added connection timeouts: WinRM (5s connection, 30s commands), SSH (5s timeout)
- Enhanced error messages with troubleshooting instructions

### 2. GSAP Animation Stalling
**Problem**: Entrance animations (fade/slide/scale) would stall on first render but work on subsequent interactions.

**Root Cause**: GSAP animations tried to run before DOM elements were fully painted by the browser.

**Solution**:
- Wrapped all GSAP animations in `requestAnimationFrame()` to wait for paint
- Changed `gsap.from()` to `gsap.fromTo()` for explicit start/end state control
- Fixed in: Dashboard.tsx, AssetCard.tsx, AssetDetail.tsx, CompareView.tsx

### 3. Domain Trust Issues
**Issue**: PC1 (Deep Freeze endpoint) had broken domain trust preventing WinRM authentication.

**Resolution**:
- Used `Test-ComputerSecureChannel -Repair` to fix trust
- Added domain user to "Remote Management Users" group
- Granted PowerShell remoting permissions via `Set-PSSessionConfiguration`

## Files Modified

| File | Changes |
|------|---------|
| `Gemfile` | Added `dotenv` gem for environment loading |
| `api/server.rb` | Added dotenv loading, fixed status endpoint to execute test command |
| `lib/patch_pilot/connections/winrm.rb` | Added 5s/30s timeouts, enhanced auth error messages |
| `lib/patch_pilot/connections/ssh.rb` | Added 5s timeout, refactored auth options |
| `bin/test_connections` | Created diagnostic utility for testing connectivity |
| `web-gui/src/components/*.tsx` | Fixed GSAP timing with requestAnimationFrame + fromTo |

## Test Results

All assets now correctly report status:
- ✅ PC1 (Deep Freeze endpoint) - Windows
- ✅ PC2, PC3 (Control endpoints) - Windows
- ✅ DC01, DM1 - Windows Server
- ✅ Fedora, Kali, Ubuntu-Docker - Linux

155 RSpec tests passing, RuboCop clean.

## Status: COMPLETE

Completed on 2026-01-27. Dashboard now accurately reports connectivity and animations render smoothly.

---

# COMPLETED: Web Dashboard (MVP)

## Overview

React-based web dashboard for visualizing and comparing patch status across all assets.

## Files Created

| File | Purpose |
|------|---------|
| `api/server.rb` | Sinatra API server wrapping PatchPilot |
| `web-gui/` | Vite + React + TypeScript frontend |
| `web-gui/src/components/` | Dashboard, AssetCard, AssetDetail, CompareView |
| `web-gui/src/api/client.ts` | API client functions |
| `web-gui/src/types/index.ts` | TypeScript interfaces |
| `bin/dashboard` | Launch script for both servers |

## Features

- [x] Dark mode DaisyUI theme
- [x] GSAP animations for smooth transitions
- [x] Dashboard view with asset cards grouped by OS
- [x] Stats showing total assets, Windows, Linux, Deep Freeze counts
- [x] Asset detail modal showing updates/packages
- [x] Compare view for side-by-side asset comparison
- [x] Deep Freeze analysis when comparing frozen vs control endpoints
- [x] API health status indicator
- [x] Environment variable loading from .env

## API Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /api/health` | Health check |
| `GET /api/inventory` | List all assets |
| `GET /api/assets/:name` | Get asset details |
| `GET /api/assets/:name/status` | Check if asset is online |
| `GET /api/assets/:name/updates` | Get updates (Windows) or packages (Linux) |
| `GET /api/compare?asset1=X&asset2=Y` | Compare two assets |

## Status: COMPLETE (MVP)

Completed on 2026-01-26. Dashboard functional with all core features.

---

# COMPLETED: Linux Package Query Module

## Overview

Query installed packages and available upgrades on Linux systems. Supports APT (Debian, Ubuntu, Kali) and DNF (Fedora, RHEL).

## Files Created

| File | Purpose |
|------|---------|
| `lib/patch_pilot/linux/package_query.rb` | Factory module + Package struct |
| `lib/patch_pilot/linux/apt_query.rb` | APT implementation (dpkg-query/apt) |
| `lib/patch_pilot/linux/dnf_query.rb` | DNF implementation (dnf list/check-update) |
| `spec/patch_pilot/linux/package_query_spec.rb` | Factory + Package struct tests |
| `spec/patch_pilot/linux/apt_query_spec.rb` | APT query tests |
| `spec/patch_pilot/linux/dnf_query_spec.rb` | DNF query tests |

## Implementation Tasks

- [x] Create `PatchPilot::Linux::Package` struct
- [x] Create `PatchPilot::Linux::PackageQuery` factory module
- [x] Implement `AptQuery` class with dpkg-query/apt parsing
- [x] Implement `DnfQuery` class with dnf output parsing
- [x] Add filtering methods (packages_matching)
- [x] Add comparison helper (compare_with)
- [x] Write tests with mocked SSH responses

## Usage

```ruby
inventory = PatchPilot.load_inventory
asset = inventory.find('ubuntu-docker')
conn = asset.connect(inventory)
conn.connect

query = PatchPilot::Linux::PackageQuery.for(conn, package_manager: 'apt')
puts query.summary
puts "Upgradable: #{query.upgradable_packages.count}"

conn.close
```

## Status: COMPLETE

Completed on 2026-01-26. 155 tests passing, RuboCop clean.

---

# COMPLETED: Windows Update Query Module

## Overview

Query installed Windows updates via PowerShell, parse results, and return structured data for comparison between Deep Freeze and control endpoints.

## Files Created

| File | Purpose |
|------|---------|
| `lib/patch_pilot/windows/update_query.rb` | Query Windows Update via PowerShell |
| `spec/patch_pilot/windows/update_query_spec.rb` | Tests with mocked responses |

## Implementation Tasks

- [x] Create `PatchPilot::Windows::UpdateQuery` class
- [x] Implement `Get-HotFix` PowerShell command execution
- [x] Parse output into structured `Update` objects (KB number, description, installed_on, installed_by)
- [x] Add filtering methods (by date range, by KB pattern)
- [x] Add comparison helper for Deep Freeze vs control endpoint analysis
- [x] Write tests with mocked WinRM responses

## Status: COMPLETE

All tasks completed on 2026-01-26. Verified against live systems.

Deep Freeze verification successful: PC1 and PC2 have identical updates installed.

---

# COMPLETED: Remote Execution Layer

## Overview

Implement the connection layer for remote command execution on Windows (WinRM) and Linux (SSH) systems.

## Files Created

| File | Purpose |
|------|---------|
| `lib/patch_pilot/connection.rb` | Base connection module and factory |
| `lib/patch_pilot/connections/winrm.rb` | WinRM implementation |
| `lib/patch_pilot/connections/ssh.rb` | SSH implementation |
| `lib/patch_pilot/credential_resolver.rb` | Environment variable expansion |

## Status: COMPLETE

All tasks completed on 2026-01-24. 76 tests passing, no RuboCop offenses.

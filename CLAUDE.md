# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Session Startup

**At the beginning of each session:**

1. **Consult `TODO.md`** for the current implementation plan and task status
2. **Read the memory MCP** (`mcp__memory__read_graph`) to recall project context and decisions
3. **Use all installed MCPs** whenever applicable - they provide valuable capabilities (memory, filesystem, sequential thinking, etc.)

## Project Purpose

**Full Scope**: Orchestrate, execute, and confirm patch management across all assets in a heterogeneous Windows/Linux environment.

**Primary Motivating Use Case**: Verify that Faronics Deep Freeze is correctly managing Windows Update on frozen endpoints. The Deep Freeze Enterprise Console provides no visibility into whether updates are actually occurring—logs only show offline/reboot events.

### Core Capabilities
1. **Query** patch status on all managed systems
2. **Orchestrate** update deployment across the environment
3. **Execute** updates remotely (WinRM for Windows, SSH for Linux)
4. **Confirm** successful installation and generate compliance reports
5. **Compare** Deep Freeze endpoint vs control endpoints to verify Deep Freeze is working

## Test Lab Environment

### Windows (Domain-Joined)
- 1 Domain Controller (AD DS, DNS)
- 1 Member Server
- 3 Windows 11 Endpoints:
  - **Endpoint #1**: Deep Freeze installed & active (PRIMARY TEST TARGET)
  - **Endpoint #2**: Control (no Deep Freeze)
  - **Endpoint #3**: Control (no Deep Freeze)

### Linux
- Fedora workstation (DNF)
- Kali box (APT)
- Ubuntu Server running Docker with containers

### Deployment Path
Phase 1: Virtualized lab → Phase 2: Physical lab at Olympic College, Bremerton, WA

## Build and Test Commands

```bash
# Run all checks (tests + linting) - default task
rake

# Run only tests
rake spec

# Run only linting
rake rubocop

# Install dependencies
bundle install
```

## Project Structure

This is a Ruby library project using:
- **Ruby 3.3.6** (specified in `.ruby-version`)
- **RSpec** for testing (`spec/` directory)
- **RuboCop** for code style enforcement
- **Rake** for task automation

Production code goes in `lib/`, executable scripts in `bin/`.

**Main module**: `PatchPilot` (see `lib/patch_pilot.rb`)

## Code Style

RuboCop is configured with `NewCops: enable` - all new cops are automatically enabled. The default `rake` task runs both tests and linting, so all code must pass RuboCop before being considered complete.

## Key Technical Decisions

### Remote Execution
- **Windows**: WinRM or PowerShell remoting (domain auth simplifies credentials)
- **Linux**: SSH with key-based authentication
- Relevant gems: `net-ssh`, `winrm`, `winrm-fs`

### Windows Update Queries
- `Get-HotFix` PowerShell cmdlet for installed updates
- `Get-WindowsUpdateLog` for update history
- Parse KB numbers and installation dates

### Linux Package Queries
- Fedora: `dnf` commands
- Kali/Ubuntu: `apt` commands

### Asset Inventory
- YAML configuration for defining managed systems
- Track: hostname, IP, OS type, Deep Freeze status (true/false)

## Implementation Priority

1. ~~Asset inventory structure (YAML) - foundation for all operations~~ **DONE**
2. ~~Remote execution layer (WinRM for Windows, SSH for Linux)~~ **DONE**
3. ~~Windows Update query module (critical for Deep Freeze verification)~~ **DONE**
4. ~~Linux package query modules (APT/DNF)~~ **DONE**
5. ~~Web Dashboard (MVP) - visualize and compare patch status~~ **DONE**
6. ~~Dashboard bugfixes (status check, animations, connectivity)~~ **DONE**
7. **Windows Update execution module (trigger updates remotely)** ← NEXT STEP
8. Linux package update execution modules (apt/dnf upgrade)
9. Confirmation/validation module (verify updates installed successfully)

## Current Status

The project is fully functional for **querying** patch status. All core query functionality is complete:
- Windows Update queries via `Get-HotFix`
- Linux package queries via APT/DNF
- Web dashboard for visualization and comparison
- Accurate connectivity testing with proper timeouts

**Next step**: Implement update execution capabilities (trigger Windows Update and Linux package updates remotely).

See **`TODO.md`** for detailed implementation plans.

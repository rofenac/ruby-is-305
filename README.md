# Ruby IS-305: Patch Management Orchestrator

A Ruby-based orchestration tool for managing and verifying patch management across a heterogeneous lab environment containing Windows and Linux systems.

## Problem Statement

**Faronics Deep Freeze** has a feature to manage Windows Update on frozen endpoints. However, the Deep Freeze Enterprise Console provides **zero visibility** into whether updates are actually occurring as scheduled—the logs only show when endpoints go offline or reboot. This project exists to independently verify that Deep Freeze is correctly managing patch deployment.

## Project Vision

This project uses Ruby as a scripting and orchestration language to:
- **Orchestrate** patch deployment across all managed systems
- **Execute** updates on Windows and Linux assets
- **Confirm** successful patch installation and compliance
- **Verify** that Deep Freeze-managed endpoints are receiving updates (primary use case)
- Compare patch levels between frozen and non-frozen Windows endpoints
- Generate compliance reports with actionable data

## Test Lab Environment (Virtualized)

### Windows Infrastructure
| System | Role | Notes |
|--------|------|-------|
| Domain Controller | AD DS, DNS | Central authentication |
| Member Server | Domain-joined | General services |
| Windows 11 Endpoint #1 | Domain-joined | **Deep Freeze installed & active** - primary test target |
| Windows 11 Endpoint #2 | Domain-joined | Control (no Deep Freeze) |
| Windows 11 Endpoint #3 | Domain-joined | Control (no Deep Freeze) |

### Linux Infrastructure
| System | Role | Notes |
|--------|------|-------|
| Fedora | Workstation | DNF package manager |
| Kali | Security tools | APT package manager |
| Ubuntu Server | Docker host | Runs containerized services |

## Deployment Plan

1. **Phase 1**: Develop and validate in the virtualized lab environment (above)
2. **Phase 2**: Scale to the physical lab at Olympic College, Bremerton, WA

## Core Capabilities

### Full Patch Management (All Assets)
- **Query** current patch status on Windows and Linux systems
- **Orchestrate** update deployment across the environment
- **Execute** updates via remote commands (WinRM/SSH)
- **Confirm** successful installation and report failures

### Deep Freeze Verification (Primary Use Case)
- Query Windows Update history on the **Deep Freeze endpoint**
- Query Windows Update history on **non-frozen control endpoints**
- Compare installed KBs, installation dates, and update compliance
- Flag discrepancies that indicate Deep Freeze update management is failing

## First Steps

### 1. Define Asset Inventory Structure
- Create a data structure to represent managed assets (hostname, OS type, IP address, Deep Freeze status)
- Use YAML for simple configuration

### 2. Implement Windows Update Query Module
- Query installed updates via PowerShell (`Get-HotFix`, `Get-WindowsUpdateLog`)
- Parse Windows Update history for installation dates and KB numbers
- This is the critical module for verifying Deep Freeze behavior

### 3. Build Remote Execution Layer
- **Windows**: WinRM or PowerShell remoting (domain-joined systems simplify auth)
- **Linux**: SSH with key-based authentication
- Consider gems: `net-ssh`, `winrm`, `winrm-fs`

### 4. Create Linux Patch Query Modules
- **Fedora**: Query DNF for available/installed updates
- **Kali/Ubuntu**: Query APT for available/installed updates
- Docker container update status (optional stretch goal)

### 5. Design Compliance Reporting
- Compare Deep Freeze endpoint vs control endpoints
- Highlight missing patches on frozen systems
- Output formats: terminal, CSV, HTML

### 6. Testing Strategy
- Write RSpec tests for each module
- Create mock responses for patch queries
- Test against live lab systems in integration tests

## Prerequisites

- Ruby 3.3.6 (see `.ruby-version`)
- Bundler for dependency management
- Network access to lab systems
- Appropriate credentials (domain admin for Windows, SSH keys for Linux)

## Getting Started

```bash
# Install dependencies
bundle install

# Run tests
rake spec

# Run linting
rake rubocop

# Run all checks (tests + linting)
rake
```

## Project Structure

```
lib/           # Production code (modules, classes)
spec/          # RSpec test files
bin/           # Executable scripts
```

## License

TBD

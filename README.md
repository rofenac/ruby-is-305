# PatchPilot: Patch Management Orchestrator

A Ruby-based orchestration tool for managing and verifying patch management across a heterogeneous lab environment containing Windows and Linux systems.

## Problem Statement

**Faronics Deep Freeze** has a feature to manage Windows Update on frozen endpoints. However, the Deep Freeze Enterprise Console provides **zero visibility** into whether updates are actually occurring as scheduled—the logs only show when endpoints go offline or reboot. This project exists to independently verify that Deep Freeze is correctly managing patch deployment.

## Current Status: MVP Complete

The core functionality is working:
- Query Windows updates and Linux packages across all managed systems
- Compare patch levels between Deep Freeze and control endpoints
- Web dashboard for visualization and comparison

## Features

### Backend (Ruby)
- **Remote Execution**: WinRM for Windows, SSH for Linux
- **Windows Update Query**: Get-HotFix parsing, filtering, comparison
- **Linux Package Query**: APT and DNF support, upgradable package detection
- **Asset Inventory**: YAML-based configuration with credential management

### Web Dashboard (React)
- Dark mode interface with DaisyUI
- Asset overview with status checking
- Detailed update/package views
- Side-by-side system comparison
- Deep Freeze analysis highlighting

## Quick Start

### Prerequisites

- Ruby 3.3.6 (see `.ruby-version`)
- Node.js 18+ (for web dashboard)
- Network access to managed systems
- Credentials configured in `.env` file

### Installation

```bash
# Install Ruby dependencies
bundle install

# Install frontend dependencies
cd web-gui && npm install && cd ..

# Copy and configure environment variables
cp .env.example .env
# Edit .env with your credentials
```

### Running the Dashboard

```bash
./bin/dashboard
```

Opens:
- Frontend: http://localhost:5173
- API: http://localhost:4567

### Running Tests

```bash
# Run all tests and linting
bundle exec rake

# Run only tests
bundle exec rake spec

# Run only linting
bundle exec rake rubocop
```

## Project Structure

```
lib/                          # Ruby library code
  patch_pilot/
    connection.rb             # Connection factory
    connections/
      winrm.rb                # Windows remote execution
      ssh.rb                  # Linux remote execution
    windows/
      update_query.rb         # Windows Update queries
    linux/
      package_query.rb        # Package query factory
      apt_query.rb            # APT package queries
      dnf_query.rb            # DNF package queries
    asset.rb                  # Asset model
    inventory.rb              # Inventory management
    credential_resolver.rb    # Environment variable expansion

api/                          # Sinatra API server
  server.rb

web-gui/                      # React frontend
  src/
    components/               # React components
    api/                      # API client
    types/                    # TypeScript interfaces

spec/                         # RSpec tests
bin/                          # Executable scripts
config/                       # Configuration files
  inventory.yml               # Asset inventory
```

## Test Lab Environment

### Windows Infrastructure
| System | Role | Notes |
|--------|------|-------|
| Domain Controller | AD DS, DNS | Central authentication |
| Member Server | Domain-joined | General services |
| Windows 11 Endpoint #1 | Domain-joined | **Deep Freeze active** - primary test target |
| Windows 11 Endpoint #2 | Domain-joined | Control (no Deep Freeze) |
| Windows 11 Endpoint #3 | Domain-joined | Control (no Deep Freeze) |

### Linux Infrastructure
| System | Role | Package Manager |
|--------|------|-----------------|
| Fedora | Workstation | DNF |
| Kali | Security tools | APT |
| Ubuntu Server | Docker host | APT |

## API Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /api/health` | Health check |
| `GET /api/inventory` | List all assets |
| `GET /api/assets/:name` | Get asset details |
| `GET /api/assets/:name/status` | Check if asset is online |
| `GET /api/assets/:name/updates` | Get updates (Windows) or packages (Linux) |
| `GET /api/compare?asset1=X&asset2=Y` | Compare two assets |

## Usage Examples

### Query Windows Updates (Ruby)

```ruby
require 'patch_pilot'

inventory = PatchPilot.load_inventory
asset = inventory.find('pc1')
conn = asset.connect(inventory)
conn.connect

query = PatchPilot::Windows::UpdateQuery.new(conn)
puts query.summary

query.installed_updates.each do |update|
  puts "#{update.kb_number} - #{update.installed_on}"
end

conn.close
```

### Query Linux Packages (Ruby)

```ruby
require 'patch_pilot'

inventory = PatchPilot.load_inventory
asset = inventory.find('ubuntu-docker')
conn = asset.connect(inventory)
conn.connect

query = PatchPilot::Linux::PackageQuery.for(conn, package_manager: 'apt')
puts "Installed: #{query.installed_packages.count}"
puts "Upgradable: #{query.upgradable_packages.count}"

conn.close
```

### Compare Deep Freeze vs Control

```ruby
# Compare two Windows endpoints
comparison = query1.compare_with(query2)
puts "Common updates: #{comparison[:common].count}"
puts "Only on PC1: #{comparison[:only_self].join(', ')}"
puts "Only on PC2: #{comparison[:only_other].join(', ')}"
```

## Roadmap

- [x] Asset inventory and configuration
- [x] Remote execution layer (WinRM/SSH)
- [x] Windows Update query module
- [x] Linux package query module (APT/DNF)
- [x] Web dashboard (MVP)
- [ ] Windows Update execution (trigger updates)
- [ ] Linux package execution (apt/dnf upgrade)
- [ ] Scheduled reports
- [ ] Historical tracking

## License

TBD

# Manual Testing Guide

## Prerequisites

1. Environment variables configured in `.env` file
2. Target systems accessible (via Tailscale or local network)
3. WinRM enabled on Windows hosts
4. SSH enabled on Linux hosts

## Connectivity Testing

### Load Environment and Test a Host

```bash
export $(grep -v '^#' .env | xargs) && bundle exec ruby bin/test_connection.rb <hostname>
```

### Available Hosts

| Hostname | OS | Description |
|----------|-----|-------------|
| `dc01` | Windows Server 2025 | Domain Controller |
| `dm1` | Windows Server 2025 | Member Server |
| `pc1` | Windows 11 | Deep Freeze endpoint (primary test target) |
| `pc2` | Windows 11 | Control endpoint |
| `pc3` | Windows 11 | Control endpoint |
| `ubuntu-docker` | Ubuntu Linux | Docker host |
| `fedora` | Fedora Linux | Workstation |
| `kali` | Kali Linux | Security box |

### Examples

```bash
# Test Windows Domain Controller
export $(grep -v '^#' .env | xargs) && bundle exec ruby bin/test_connection.rb dc01

# Test Deep Freeze endpoint
export $(grep -v '^#' .env | xargs) && bundle exec ruby bin/test_connection.rb pc1

# Test Linux Docker host
export $(grep -v '^#' .env | xargs) && bundle exec ruby bin/test_connection.rb ubuntu-docker
```

### Expected Output

```
Loading inventory...
Connecting to dc01 (172.29.70.10)...
  OS: windows_server
  Credential: windows_domain
Connected! Running 'hostname' command...

Result:
  stdout: DC1
  exit_code: 0

Connection test successful!
```

## Windows Update Query Testing

### Query Updates on a Single Host

```bash
export $(grep -v '^#' .env | xargs) && bundle exec ruby -e "
require_relative 'lib/patch_pilot'

inventory = PatchPilot.load_inventory
asset = inventory.find('dc01')
conn = asset.connect(inventory)
conn.connect

query = PatchPilot::Windows::UpdateQuery.new(conn)
puts query.summary
puts
query.installed_updates.each { |u| puts \"#{u.kb_number} - #{u.installed_on}\" }

conn.close
"
```

### Compare Deep Freeze vs Control Endpoint

```bash
export $(grep -v '^#' .env | xargs) && bundle exec ruby -e "
require_relative 'lib/patch_pilot'

inventory = PatchPilot.load_inventory

# Deep Freeze endpoint
pc1 = inventory.find('pc1')
conn1 = pc1.connect(inventory)
conn1.connect
query1 = PatchPilot::Windows::UpdateQuery.new(conn1)

# Control endpoint
pc2 = inventory.find('pc2')
conn2 = pc2.connect(inventory)
conn2.connect
query2 = PatchPilot::Windows::UpdateQuery.new(conn2)

# Compare
comparison = query1.compare_with(query2)
puts \"Common: #{comparison[:common].count}\"
puts \"Only PC1: #{comparison[:only_self].join(', ')}\"
puts \"Only PC2: #{comparison[:only_other].join(', ')}\"

conn1.close
conn2.close
"
```

## Linux Package Query Testing

### Query Packages on a Linux Host

```bash
export $(grep -v '^#' .env | xargs) && bundle exec ruby -e "
require_relative 'lib/patch_pilot'

inventory = PatchPilot.load_inventory
asset = inventory.find('ubuntu-docker')
conn = asset.connect(inventory)
conn.connect

query = PatchPilot::Linux::PackageQuery.for(conn, package_manager: 'apt')
puts query.summary
puts
puts 'Upgradable packages:'
query.upgradable_packages.each { |p| puts \"  #{p.name} -> #{p.version}\" }

conn.close
"
```

### Compare Two Linux Hosts

```bash
export $(grep -v '^#' .env | xargs) && bundle exec ruby -e "
require_relative 'lib/patch_pilot'

inventory = PatchPilot.load_inventory

# Ubuntu host
ubuntu = inventory.find('ubuntu-docker')
conn1 = ubuntu.connect(inventory)
conn1.connect
query1 = PatchPilot::Linux::PackageQuery.for(conn1, package_manager: 'apt')

# Kali host
kali = inventory.find('kali')
conn2 = kali.connect(inventory)
conn2.connect
query2 = PatchPilot::Linux::PackageQuery.for(conn2, package_manager: 'apt')

# Compare
comparison = query1.compare_with(query2)
puts \"Common packages: #{comparison[:common].count}\"
puts \"Only Ubuntu: #{comparison[:only_self].count}\"
puts \"Only Kali: #{comparison[:only_other].count}\"

conn1.close
conn2.close
"
```

## Windows Update Execution

### IRB Session

```bash
bundle exec irb -r ./lib/patch_pilot -r dotenv/load
```

```ruby
inv = PatchPilot.load_inventory
asset = inv.find('PC2')  # Control endpoint, no Deep Freeze
conn = asset.connect(inv)
conn.connect

executor = PatchPilot::Windows::UpdateExecutor.new(conn)

# 1. Search (read-only)
available = executor.available_updates
available.each { |u| puts "#{u.kb_number} - #{u.title} (#{u.size_mb} MB)" }

# 2. Download only (no install)
# executor.download_updates

# 3. Install specific KBs
# executor.install_updates(kb_numbers: ['KB5073379'])

# 4. Install all available
# executor.install_updates

executor.reboot_required?
conn.close
```

### Targeted Spec

```bash
rake spec SPEC=spec/patch_pilot/windows/update_executor_spec.rb
```

## Linux Package Execution

### IRB Session

```ruby
inv = PatchPilot.load_inventory
asset = inv.find('docker')
conn = asset.connect(inv)
conn.connect

executor = PatchPilot::Linux::PackageExecutor.for(conn, package_manager: asset.package_manager)

result = executor.upgrade_all
puts "Success: #{result.succeeded?}, Upgraded: #{result.upgraded_count}"
puts result.upgraded_packages.join(', ')

# Or target specific packages:
# result = executor.upgrade_packages(packages: ['curl', 'vim'])

executor.reboot_required?
conn.close
```

### Targeted Specs

```bash
rake spec SPEC=spec/patch_pilot/linux/apt_executor_spec.rb
rake spec SPEC=spec/patch_pilot/linux/dnf_executor_spec.rb
```

### Recommended Live Test Order

| Step | Target | Action | Risk |
|------|--------|--------|------|
| 1 | PC2 | `available_updates` | None (read-only) |
| 2 | PC2 | `download_updates` | Low (download only) |
| 3 | PC2 | `install_updates` | Medium (installs updates) |
| 4 | docker | `upgrade_all` | Medium (least critical Linux) |
| 5 | PC1 | Full cycle | High (thaw Deep Freeze first) |

## Web Dashboard

### Running the Dashboard

The web dashboard provides a visual interface for viewing and comparing assets.

**Option 1: Use the launcher script (recommended)**

```bash
./bin/dashboard
```

This starts both servers and opens:
- Frontend: http://localhost:5173
- API: http://localhost:4567

Press `Ctrl+C` to stop both servers.

**Option 2: Run servers separately**

```bash
# Terminal 1 - Start the Ruby API server
export $(grep -v '^#' .env | xargs) && bundle exec ruby api/server.rb

# Terminal 2 - Start the Vite frontend dev server
cd web-gui && npm run dev
```

### Dashboard Features

- **Dashboard View**: Shows all assets grouped by OS (Windows/Linux) with stats
- **Asset Details**: Click "View Details" to see installed updates (Windows) or packages (Linux)
- **Compare View**: Select two assets to compare their updates/packages side-by-side
- **Deep Freeze Analysis**: Automatically highlights differences when comparing frozen vs control endpoints

### API Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /api/health` | Health check |
| `GET /api/inventory` | List all assets |
| `GET /api/assets/:name` | Get asset details |
| `GET /api/assets/:name/status` | Check if asset is online |
| `GET /api/assets/:name/updates` | Get updates (Windows) or packages (Linux) |
| `GET /api/compare?asset1=X&asset2=Y` | Compare two assets |

### Testing the API Directly

```bash
# Health check
curl http://localhost:4567/api/health

# List inventory
curl http://localhost:4567/api/inventory

# Get asset details
curl http://localhost:4567/api/assets/dc01

# Compare two Windows endpoints
curl "http://localhost:4567/api/compare?asset1=pc1&asset2=pc2"
```

## Running Automated Tests

```bash
# Run all tests and linting
bundle exec rake

# Run only tests
bundle exec rake spec

# Run only linting
bundle exec rake rubocop
```

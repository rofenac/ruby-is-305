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

## Running Automated Tests

```bash
# Run all tests and linting
bundle exec rake

# Run only tests
bundle exec rake spec

# Run only linting
bundle exec rake rubocop
```

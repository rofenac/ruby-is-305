# Manual Testing Guide

## Prerequisites

1. Environment variables configured in `.env` file
2. Target systems accessible on lab network (**Tailscale must be OFF**)
3. WinRM enabled on Windows hosts
4. SSH enabled on Linux hosts

## Connectivity Testing

### Load Environment and Test a Host

```bash
export $(grep -v '^#' .env | xargs) && bundle exec ruby bin/test_connection.rb <hostname>
```

### Available Hosts

| Hostname | IP | OS | Role | Notes |
|---|---|---|---|---|
| `dc1` | 192.168.1.0 | Windows Server 2016 | `domain_controller` | |
| `dc4` | 192.168.1.4 | Windows Server 2019 | `domain_controller` | |
| `dm4` | 192.168.1.30 | Windows Server 2022 | `member_server` | |
| `hyperv1` | 192.168.1.100 | Windows Server 2025 | `member_server` | Hyper-V host |
| `cis1` | 192.168.1.60 | RHEL | `server` | Linux server (cis1 creds) |
| `prod-docker` | 192.168.1.101 | Ubuntu | `docker_host` | Docker host (prod_docker creds) |
| `t215-01`..`t215-24` | 192.168.8.1–.24 | Windows 11 | `endpoint` | Student endpoints, Deep Freeze ON |
| `t215-25` | 192.168.8.25 | Windows 11 | `teacher_workstation` | No Deep Freeze |
| `t215-26`..`t215-28` | 192.168.8.26–.28 | Windows 11 | `hot_spare` | No Deep Freeze |
| `t215-nmws` | 192.168.11.1 | Windows 11 | `monitoring_workstation` | Network monitoring (primary) |
| `t215b-nmws` | 192.168.11.2 | Windows 11 | `monitoring_workstation` | Network monitoring (backup) |
| `sb3` | 192.168.0.254:6013 | Kali | `sandbox` | Via PAT (linux_ssh creds) |
| `sb4` | 192.168.0.254:6014 | Fedora Security | `sandbox` | Via PAT (linux_ssh creds) |

### Examples

```bash
# Test Domain Controller
export $(grep -v '^#' .env | xargs) && bundle exec ruby bin/test_connection.rb dc1

# Test a Deep Freeze student endpoint
export $(grep -v '^#' .env | xargs) && bundle exec ruby bin/test_connection.rb t215-01

# Test a control endpoint
export $(grep -v '^#' .env | xargs) && bundle exec ruby bin/test_connection.rb t215-25

# Test Linux Docker host
export $(grep -v '^#' .env | xargs) && bundle exec ruby bin/test_connection.rb prod-docker

# Test sandbox (via PAT router)
export $(grep -v '^#' .env | xargs) && bundle exec ruby bin/test_connection.rb sb3
```

### Expected Output

```
Loading inventory...
Connecting to dc1 (192.168.1.0)...
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
asset = inventory.find('dc1')
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

# Deep Freeze student endpoint
frozen = inventory.find('t215-01')
conn1 = frozen.connect(inventory)
conn1.connect
query1 = PatchPilot::Windows::UpdateQuery.new(conn1)

# Control endpoint (teaching workstation)
control = inventory.find('t215-25')
conn2 = control.connect(inventory)
conn2.connect
query2 = PatchPilot::Windows::UpdateQuery.new(conn2)

# Compare
comparison = query1.compare_with(query2)
puts \"Common: #{comparison[:common].count}\"
puts \"Only frozen: #{comparison[:only_self].join(', ')}\"
puts \"Only control: #{comparison[:only_other].join(', ')}\"

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
asset = inventory.find('prod-docker')
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

docker = inventory.find('prod-docker')
conn1 = docker.connect(inventory)
conn1.connect
query1 = PatchPilot::Linux::PackageQuery.for(conn1, package_manager: 'apt')

sb3 = inventory.find('sb3')
conn2 = sb3.connect(inventory)
conn2.connect
query2 = PatchPilot::Linux::PackageQuery.for(conn2, package_manager: 'apt')

comparison = query1.compare_with(query2)
puts \"Common packages: #{comparison[:common].count}\"
puts \"Only prod-docker: #{comparison[:only_self].count}\"
puts \"Only sb3: #{comparison[:only_other].count}\"

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

# Use a control endpoint (no Deep Freeze) — t215-25 (teacher) or t215-26..28 (hot spares)
asset = inv.find('t215-25')
conn = asset.connect(inv)
conn.connect

executor = PatchPilot::Windows::UpdateExecutor.new(conn)

# 1. Search (read-only)
available = executor.available_updates
available.each { |u| puts "#{u.kb_number} - #{u.title} (#{u.size_mb} MB)" }

# 2. Install specific KBs
# executor.install_updates(kb_numbers: ['KB5073379'])

# 3. Install all available
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
asset = inv.find('prod-docker')
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
|---|---|---|---|
| 1 | t215-25 | `available_updates` | None (read-only) |
| 2 | t215-25 | `install_updates` | Medium |
| 3 | prod-docker | `upgrade_all` | Medium |
| 4 | t215-01 | Full cycle | High (thaw Deep Freeze first) |

## Web Dashboard

### Running the Dashboard

```bash
./bin/dashboard
```

- Frontend: http://localhost:5173
- API: http://localhost:4567

Press `Ctrl+C` to stop both servers.

### Run Servers Separately

```bash
# Terminal 1
export $(grep -v '^#' .env | xargs) && bundle exec ruby api/server.rb

# Terminal 2
cd web-gui && npm run dev
```

### API Endpoints

| Endpoint | Description |
|---|---|
| `GET /api/health` | Health check (public — no auth required) |
| `GET /api/auth/verify` | Validate credentials — returns 200 or 401 |
| `GET /api/inventory` | List all assets (includes `os_version`, `role`, `tags`) |
| `GET /api/assets/:name` | Get asset details (includes `os_version`, `role`, `tags`) |
| `GET /api/assets/:name/status` | Check if asset is online |
| `GET /api/assets/:name/updates` | Get updates (Windows) or packages (Linux) |
| `GET /api/assets/:name/updates/available` | Search available updates |
| `POST /api/assets/:name/updates/install` | Install updates (409 if reboot pending or Deep Freeze) |
| `POST /api/assets/:name/packages/upgrade` | Upgrade Linux packages (409 if reboot pending) |
| `GET /api/assets/:name/reboot-status` | Check reboot pending |
| `POST /api/assets/:name/reboot` | Trigger reboot |
| `GET /api/compare?asset1=X&asset2=Y` | Compare two assets |

### Testing the API Directly

Auth is required for all endpoints except `/api/health`. Set `PATCHPILOT_AUTH_USERNAME` and `PATCHPILOT_AUTH_PASSWORD` in docker-compose or `.env`, then pass credentials with `-u`:

```bash
curl http://localhost:4567/api/health
curl -u patchpilot:change-me http://localhost:4567/api/auth/verify
curl -u patchpilot:change-me http://localhost:4567/api/inventory
curl -u patchpilot:change-me http://localhost:4567/api/assets/dc1
curl -u patchpilot:change-me "http://localhost:4567/api/compare?asset1=t215-01&asset2=t215-25"
```

## Running Automated Tests

```bash
bundle exec rake          # tests + rubocop
bundle exec rake spec     # tests only
bundle exec rake rubocop  # lint only
```

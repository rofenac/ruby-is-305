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

## Running Automated Tests

```bash
# Run all tests and linting
bundle exec rake

# Run only tests
bundle exec rake spec

# Run only linting
bundle exec rake rubocop
```

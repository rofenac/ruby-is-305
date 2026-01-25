# TODO: Project Task Tracking

---

# NEXT: Windows Update Query Module

## Overview

Query installed Windows updates via PowerShell, parse results, and return structured data for comparison between Deep Freeze and control endpoints.

**Prerequisite**: Lab environment with Windows systems running and accessible via WinRM.

## Files to Create

| File | Purpose |
|------|---------|
| `lib/patch_pilot/windows/update_query.rb` | Query Windows Update via PowerShell |
| `spec/patch_pilot/windows/update_query_spec.rb` | Tests with mocked responses |

## Implementation Tasks

- [ ] Create `PatchPilot::Windows::UpdateQuery` class
- [ ] Implement `Get-HotFix` PowerShell command execution
- [ ] Parse output into structured `Update` objects (KB number, description, installed_on, installed_by)
- [ ] Add filtering methods (by date range, by KB pattern)
- [ ] Add comparison helper for Deep Freeze vs control endpoint analysis
- [ ] Write tests with mocked WinRM responses

## Usage (planned)

```ruby
inventory = PatchPilot.load_inventory
asset = inventory.find('win11-df')
conn = asset.connect(inventory)

query = PatchPilot::Windows::UpdateQuery.new(conn)
updates = query.installed_updates

updates.each do |update|
  puts "#{update.kb_number} - #{update.installed_on}"
end
```

---

# COMPLETED: Remote Execution Layer

## Overview

Implement the connection layer for remote command execution on Windows (WinRM) and Linux (SSH) systems.

## Files to Create

| File | Purpose |
|------|---------|
| `lib/patch_pilot/connection.rb` | Base connection module and factory |
| `lib/patch_pilot/connections/winrm.rb` | WinRM implementation |
| `lib/patch_pilot/connections/ssh.rb` | SSH implementation |
| `lib/patch_pilot/credential_resolver.rb` | Environment variable expansion |
| `spec/patch_pilot/connection_spec.rb` | Connection factory tests |
| `spec/patch_pilot/connections/winrm_spec.rb` | WinRM tests |
| `spec/patch_pilot/connections/ssh_spec.rb` | SSH tests |
| `spec/patch_pilot/credential_resolver_spec.rb` | Credential resolver tests |

## Files to Modify

| File | Changes |
|------|---------|
| `Gemfile` | Add `winrm`, `net-ssh` gems |
| `lib/patch_pilot.rb` | Require new modules |
| `lib/patch_pilot/asset.rb` | Add `#connect` method |
| `lib/patch_pilot/inventory.rb` | Use credential resolver |
| `spec/patch_pilot/asset_spec.rb` | Add connection tests |

## Implementation Tasks

### 1. Add Dependencies to Gemfile

```ruby
gem 'winrm', '~> 2.3'
gem 'net-ssh', '~> 7.2'
```

Run `bundle install` after adding.

---

### 2. Create Credential Resolver

**File**: `lib/patch_pilot/credential_resolver.rb`

Expands environment variable placeholders like `${DOMAIN_ADMIN_USER}`:

```ruby
module PatchPilot
  class CredentialResolver
    def self.resolve(credentials_hash)
      # Deep clone and expand ${VAR} patterns
    end
  end
end
```

---

### 3. Create Base Connection Module

**File**: `lib/patch_pilot/connection.rb`

Factory pattern to create appropriate connection type:

```ruby
module PatchPilot
  module Connection
    Result = Struct.new(:stdout, :stderr, :exit_code, keyword_init: true)

    class Error < PatchPilot::Error; end
    class AuthenticationError < Error; end
    class ConnectionError < Error; end
    class CommandError < Error; end

    def self.for(asset, credentials)
      # Returns WinRM or SSH connection based on asset.os
    end
  end
end
```

---

### 4. Create WinRM Connection

**File**: `lib/patch_pilot/connections/winrm.rb`

```ruby
module PatchPilot
  module Connections
    class WinRM
      def initialize(host:, username:, password:, domain: nil, port: 5985)
      def connect
      def execute(command) -> Connection::Result
      def close
    end
  end
end
```

---

### 5. Create SSH Connection

**File**: `lib/patch_pilot/connections/ssh.rb`

```ruby
module PatchPilot
  module Connections
    class SSH
      def initialize(host:, username:, key_file: nil, password: nil, port: 22)
      def connect
      def execute(command) -> Connection::Result
      def close
    end
  end
end
```

---

### 6. Add Asset#connect Method

**File**: `lib/patch_pilot/asset.rb`

```ruby
def connect(inventory)
  creds = inventory.credential(credential_ref)
  Connection.for(self, creds)
end
```

---

### 7. Update Inventory#credential

Integrate credential resolver to expand env vars when credentials are fetched.

---

### 8. Update Main Module Requires

**File**: `lib/patch_pilot.rb`

Add requires for new modules.

---

## Testing Strategy

- **Unit tests**: Mock WinRM/SSH libraries, test connection logic
- **Integration tests**: Mark with `:integration` tag, skip by default

---

## Verification

1. Run `bundle install` to install new gems
2. Run `rake` to verify all tests pass and RuboCop is satisfied
3. Manual verification (when lab available):
   ```ruby
   inventory = PatchPilot.load_inventory
   asset = inventory.find('dc01')
   conn = asset.connect(inventory)
   result = conn.execute('hostname')
   puts result.stdout  # => "dc01"
   ```

---

## Order of Implementation

- [x] Add gems to Gemfile, run `bundle install`
- [x] Create `CredentialResolver` with tests
- [x] Update `Inventory#credential` to use resolver
- [x] Create `Connection` module with Result struct and exceptions
- [x] Create `Connections::WinRM` with tests
- [x] Create `Connections::SSH` with tests
- [x] Add `Asset#connect` method with tests
- [x] Update `lib/patch_pilot.rb` requires
- [x] Run `rake` to verify everything passes

## Status: COMPLETE

All tasks completed on 2026-01-24. 76 tests passing, no RuboCop offenses.

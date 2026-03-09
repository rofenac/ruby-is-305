# PatchPilot

Patch management orchestrator for heterogeneous Windows/Linux environments.

PatchPilot remotely queries, compares, and orchestrates patch management across Windows and Linux systems — built to prove that Faronics Deep Freeze is actually doing its job when the Deep Freeze console won't tell you.

---

## Prerequisites

### System packages

#### Debian / Ubuntu

```bash
sudo apt update
sudo apt install -y build-essential libssl-dev libz-dev autoconf bison \
  curl git libgdbm-dev libncurses5-dev libreadline-dev libffi-dev libyaml-dev
```

#### Arch Linux

```bash
sudo pacman -Syu
sudo pacman -S --needed base-devel openssl zlib autoconf bison \
  curl git gdbm ncurses readline libffi libyaml
```

### Ruby 3.3.6 (via rbenv)

Neither Ubuntu's default repos nor Arch's system Ruby are guaranteed to ship Ruby 3.3.x. Use [rbenv](https://github.com/rbenv/rbenv) to pin the correct version.

#### Debian / Ubuntu — install rbenv via the curl installer

```bash
curl -fsSL https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer | bash

# bash:
echo 'eval "$(~/.rbenv/bin/rbenv init - bash)"' >> ~/.bashrc
source ~/.bashrc
# zsh:
# echo 'eval "$(~/.rbenv/bin/rbenv init - zsh)"' >> ~/.zshrc
# source ~/.zshrc
```

#### Arch Linux — install rbenv via pacman

```bash
sudo pacman -S rbenv ruby-build

# bash:
echo 'eval "$(rbenv init - bash)"' >> ~/.bashrc
source ~/.bashrc
# zsh:
# echo 'eval "$(rbenv init - zsh)"' >> ~/.zshrc
# source ~/.zshrc
```

> **Note:** On Arch, `erb` is split into its own package and is required to build Ruby. Install it before running `rbenv install`:
> ```bash
> sudo pacman -S ruby-erb
> ```

#### All distros — install Ruby 3.3.6

```bash
rbenv install 3.3.6
rbenv global 3.3.6

# Verify
ruby -v   # Should print ruby 3.3.6
```

### Bundler

```bash
gem install bundler
```

### Node.js 20+ (via nvm)

The Vite/React frontend requires Node.js. Install via [nvm](https://github.com/nvm-sh/nvm):

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash

# Reload your shell config (adjust for zsh if needed)
source ~/.bashrc

nvm install 20
nvm use 20

# Verify
node -v   # Should print v20.x.x
npm -v
```

---

## Installation

### 1. Clone the repository

```bash
git clone https://github.com/your-org/ruby-is-305.git
cd ruby-is-305
```

### 2. Install Ruby dependencies

```bash
bundle install
```

### 3. Install frontend dependencies

```bash
cd web-gui && npm install && cd ..
```

### 4. Configure credentials

```bash
cp .env.example .env
```

Edit `.env` with your actual credentials. The inventory references these variables for WinRM and SSH authentication:

```
DOMAIN_ADMIN_USER=<domain admin username>
DOMAIN_ADMIN_PASSWORD=<domain admin password>
DOMAIN_NAME=<domain name>

SSH_USER=<SSH username for general lab Linux hosts>
SSH_PASSWORD=<SSH password>
SSH_SUDO_PASSWORD=<sudo password (may match SSH_PASSWORD)>

PROD_DOCKER_SSH_USER=<prod-docker SSH username>
PROD_DOCKER_SSH_PASSWORD=<prod-docker SSH password>
PROD_DOCKER_SUDO_PASSWORD=<prod-docker sudo password>

CIS1_SSH_USER=<cis1 SSH username>
CIS1_SSH_PASSWORD=<cis1 SSH password>
CIS1_SUDO_PASSWORD=<cis1 sudo password>
```

### 5. Configure the asset inventory

Edit `config/inventory.yml` to match your environment. Each asset needs a hostname, IP, OS type, and credential reference. See the existing entries for examples.

---

## Launch

```bash
./bin/dashboard
```

This starts both the Sinatra API server and the Vite dev server:

| Service | URL |
|---|---|
| Frontend | http://localhost:5173 |
| API | http://localhost:4567 |

Press `Ctrl+C` to stop both.

### Running the API server standalone

If you only need the API without the frontend:

```bash
bundle exec ruby api/server.rb
```

The API will be available at `http://localhost:4567`. Test it with:

```bash
curl http://localhost:4567/api/health
```

---

## Troubleshooting

### API won't start

- **`bundle exec` not found / gem errors**: Make sure you ran `bundle install` and are using the correct Ruby version (`ruby -v` should show `3.3.6`). If using rbenv, run `rbenv rehash` after installing bundler.
- **Missing `.env`**: The API loads credentials via `dotenv`. If `.env` is missing, the server will still start but all connection attempts to managed assets will fail.
- **Port 4567 already in use**: Another process is bound to the Sinatra default port. Kill it with `lsof -i :4567` or change the port.

### Frontend can't reach the API

- The Vite dev server proxies `/api` requests to `http://localhost:4567` (configured in `web-gui/vite.config.ts`). The API server **must** be running for the frontend to work.
- If you started the frontend separately (`cd web-gui && npm run dev`), make sure the API is also running in another terminal.
- Check the browser console for CORS or network errors — if you see `ECONNREFUSED` on port 4567, the API isn't running.

### WinRM / SSH connection failures

- Verify the target machine IPs in `config/inventory.yml` are reachable from your server (`ping <ip>`).
- WinRM (Windows): Port 5985 must be open. WinRM must be enabled on the target (`winrm quickconfig`). The domain account needs admin privileges.
- SSH (Linux): Port 22 must be open (sandbox hosts use custom ports via PAT — see `config/inventory.yml`). Password authentication is used; ensure `SSH_USER` and `SSH_PASSWORD` are set in `.env`.
- **Tailscale**: must be disabled when connecting to the lab. It silently hijacks routing and breaks connections.
- Check that `.env` credentials are correct and the variables match what `config/inventory.yml` references (`${DOMAIN_ADMIN_USER}`, etc.).

---

## Tests

```bash
rake            # Tests + linting
rake spec       # Tests only
rake rubocop    # Linting only
```

---

## Project Structure

```
lib/            Production code (PatchPilot module)
api/            Sinatra API server (server.rb)
web-gui/        Vite/React/TypeScript frontend
bin/            Scripts (dashboard launcher, test_connections)
config/         Asset inventory (inventory.yml)
spec/           RSpec tests
```

# PatchPilot

Patch management orchestrator for mixed Windows and Linux environments.

PatchPilot remotely queries, compares, and drives patch activity across lab systems. In development, it runs as a Sinatra API plus a Vite/React frontend. In production, it runs as a single Docker container that serves the built frontend from the Ruby app and protects the UI/API with simple HTTP Basic auth.

## Choose a workflow

Use one of these paths depending on what you need:

- **Local development**: install Ruby, Node.js, and build tools. Use this when you will change code, run tests, or work on the UI.
- **Production image build only**: install Docker and Git only. Use this when you just want to build the image locally, transfer it to the production server, and deploy there.

Both paths are documented below.

---

## Local development setup

These instructions assume a fresh machine with no project dependencies installed.

### 1. Install base system packages

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

### 2. Install Ruby 3.3.6 with rbenv

This project expects Ruby `3.3.6`.

#### Debian / Ubuntu

```bash
curl -fsSL https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer | bash

# bash
echo 'eval "$(~/.rbenv/bin/rbenv init - bash)"' >> ~/.bashrc
source ~/.bashrc

# zsh
# echo 'eval "$(~/.rbenv/bin/rbenv init - zsh)"' >> ~/.zshrc
# source ~/.zshrc
```

#### Arch Linux

```bash
sudo pacman -S rbenv ruby-build

# bash
echo 'eval "$(rbenv init - bash)"' >> ~/.bashrc
source ~/.bashrc

# zsh
# echo 'eval "$(rbenv init - zsh)"' >> ~/.zshrc
# source ~/.zshrc
```

On Arch, install `ruby-erb` before building Ruby:

```bash
sudo pacman -S ruby-erb
```

Install and verify Ruby:

```bash
rbenv install 3.3.6
rbenv global 3.3.6
ruby -v
```

### 3. Install Bundler

```bash
gem install bundler
rbenv rehash
```

### 4. Install Node.js 20+ with nvm

The frontend uses Vite and React.

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash

# Reload your shell config. Adjust for zsh if needed.
source ~/.bashrc

nvm install 20
nvm use 20
node -v
npm -v
```

### 5. Clone the repository

```bash
git clone https://github.com/your-org/ruby-is-305.git
cd ruby-is-305
```

### 6. Install project dependencies

Ruby gems:

```bash
bundle install
```

Frontend dependencies:

```bash
cd web-gui
npm install
cd ..
```

### 7. Configure credentials

Create your `.env` file from the example:

```bash
cp .env.example .env
```

Edit `.env` and fill in the values you actually use:

```dotenv
DOMAIN_ADMIN_USER=<domain_admin_username>
DOMAIN_ADMIN_PASSWORD=<domain_admin_password>
DOMAIN_NAME=<domain_name>

SSH_USER=<ssh_username>
SSH_PASSWORD=<ssh_password>
SSH_SUDO_PASSWORD=<ssh_sudo_password>

PROD_DOCKER_SSH_USER=<prod_docker_username>
PROD_DOCKER_SSH_PASSWORD=<prod_docker_password>
PROD_DOCKER_SUDO_PASSWORD=<prod_docker_sudo_password>

CIS1_SSH_USER=<cis1_username>
CIS1_SSH_PASSWORD=<cis1_password>
CIS1_SUDO_PASSWORD=<cis1_sudo_password>
```

### 8. Configure the inventory

Create your inventory file from the example:

```bash
cp config/inventory.yml.example config/inventory.yml
```

Edit `config/inventory.yml` to match your environment. Each asset needs a hostname, IP, OS type, and credential reference.

### 9. Verify the development environment

Run the test and lint suite:

```bash
rake
```

Or run the checks separately:

```bash
bundle exec rspec
bundle exec rubocop
cd web-gui && npm run lint && npm run build && cd ..
```

### 10. Run the app in development

The development dashboard launcher starts the Ruby API and the Vite dev server:

```bash
./bin/dashboard
```

URLs:

- Frontend: `http://localhost:5173`
- API: `http://localhost:4567`

The API can also be run standalone:

```bash
bundle exec ruby api/server.rb
```

Health check:

```bash
curl http://localhost:4567/api/health
```

---

## Production image build-only workflow

Use this path if you are not developing locally and only want to build the production image, transfer it, and deploy it on another server.

### What you need on the local build machine

- Git
- Docker

You do **not** need Ruby, Bundler, or Node.js installed locally for this path. The `Dockerfile` handles the frontend build and Ruby bundle inside the image build.

### 1. Clone the repository

```bash
git clone https://github.com/your-org/ruby-is-305.git
cd ruby-is-305
```

### 2. Build the image locally

Pick a tag and build it:

```bash
docker build -t patchpilot:latest .
```

You can use a dated tag if you prefer:

```bash
docker build -t patchpilot:2026-03-13 .
```

### 3. Export and compress the image

```bash
docker save patchpilot:latest -o patchpilot.tar
gzip -9 patchpilot.tar
```

This produces `patchpilot.tar.gz`.

### 4. Copy the deployment artifacts to the production server

At minimum, copy:

- the image tarball
- `docker-compose.yml.example` copied and renamed to `docker-compose.yml`
- the production `.env`
- the production `inventory.yml`

Example:

```bash
cp docker-compose.yml.example docker-compose.yml
scp patchpilot.tar.gz docker-compose.yml .env config/inventory.yml user@your-server:/opt/patchpilot/
```

---

## Production server deployment

These steps assume the image was built on another machine and copied to the server.

### What you need on the production server

- Docker Engine
- Docker Compose plugin available as `docker compose`

The production server does **not** need Ruby, Bundler, Node.js, or the full source tree.

### 1. Create a deployment directory

```bash
mkdir -p /opt/patchpilot
cd /opt/patchpilot
```

Make sure these files are present there:

- `patchpilot.tar.gz`
- `docker-compose.yml`
- `.env`
- `inventory.yml`

### 2. Load the image into Docker

```bash
gunzip -f patchpilot.tar.gz
docker load -i patchpilot.tar
```

If your Compose file uses a different image tag, make sure it matches the tag you loaded.

### 3. Review the Compose file

The sample Compose file is [docker-compose.yml.example](/home/rofenac/github/ruby-is-305/docker-compose.yml.example). It is meant for a prebuilt image workflow and expects:

- `image: patchpilot:latest`
- a named volume called `patch_pilot`
- HTTP Basic auth env vars
- `PATCHPILOT_INVENTORY_PATH=/var/lib/patchpilot/inventory.yml`

Set these values before deploying:

```yaml
PATCHPILOT_AUTH_USERNAME: patchpilot
PATCHPILOT_AUTH_PASSWORD: change-me
PATCHPILOT_ALLOWED_CORS_CIDRS: 192.168.0.0/16
PATCHPILOT_INVENTORY_PATH: /var/lib/patchpilot/inventory.yml
```

### 4. Seed the named volume with `inventory.yml`

Create the named volume:

```bash
docker volume create patch_pilot
```

Copy your `inventory.yml` into it using the already-loaded image:

```bash
docker run --rm \
  -v patch_pilot:/var/lib/patchpilot \
  -v "$PWD/inventory.yml":/seed/inventory.yml:ro \
  patchpilot:latest \
  sh -lc 'cp /seed/inventory.yml /var/lib/patchpilot/inventory.yml'
```

If you use a non-`latest` image tag, replace `patchpilot:latest` in that command.

### 5. Start the stack

```bash
docker compose up -d
```

If you deploy through Portainer, use the same Compose contents and the same env values. The loaded image must already exist on the server.

### 6. Verify the deployment

Check the container:

```bash
docker compose ps
docker compose logs -f
```

Health check:

```bash
curl http://<server-ip>:4567/api/health
```

Open the UI at:

```text
http://<server-ip>:4567
```

The main UI and API are protected by HTTP Basic auth. The health endpoint is intentionally left unauthenticated for simple container health checks.

---

## Environment variables summary

### Runtime credentials from `.env`

- `DOMAIN_ADMIN_USER`
- `DOMAIN_ADMIN_PASSWORD`
- `DOMAIN_NAME`
- `SSH_USER`
- `SSH_PASSWORD`
- `SSH_SUDO_PASSWORD`
- `PROD_DOCKER_SSH_USER`
- `PROD_DOCKER_SSH_PASSWORD`
- `PROD_DOCKER_SUDO_PASSWORD`
- `CIS1_SSH_USER`
- `CIS1_SSH_PASSWORD`
- `CIS1_SUDO_PASSWORD`

### App-level production variables

- `PATCHPILOT_AUTH_USERNAME`
- `PATCHPILOT_AUTH_PASSWORD`
- `PATCHPILOT_ALLOWED_CORS_CIDRS`
- `PATCHPILOT_INVENTORY_PATH`
- `PORT` (optional, defaults to `4567`)
- `PATCHPILOT_BIND` (optional, defaults to `0.0.0.0`)

---

## Troubleshooting

### Development setup issues

- If `bundle install` fails, verify `ruby -v` shows `3.3.6`.
- If `bundle exec` cannot find new gems after installing Bundler with rbenv, run `rbenv rehash`.
- If the frontend fails to start, verify `node -v` is `20.x` or newer.
- If the dashboard shows connection failures, verify `.env` and `config/inventory.yml` match each other.

### Production deployment issues

- If the UI returns `401`, verify `PATCHPILOT_AUTH_USERNAME` and `PATCHPILOT_AUTH_PASSWORD` in the Compose file.
- If the container starts but assets are missing, verify `PATCHPILOT_INVENTORY_PATH` matches the path inside the `patch_pilot` volume.
- If `docker compose up -d` says the image is missing, verify `docker load -i patchpilot.tar` completed and the image tag matches the Compose file.
- If WinRM or SSH connections fail, confirm the container host can actually reach the target IPs on the required ports.

---

## Project structure

```text
api/            Sinatra API server
bin/            Development scripts
config/         Inventory examples and local inventory file
lib/            PatchPilot Ruby code
spec/           RSpec test suite
web-gui/        React/Vite frontend
Dockerfile      Production image build
config.ru       Puma/Rack entrypoint
```

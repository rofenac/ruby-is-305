# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## !! ABSOLUTE RULE — NO GIT COMMANDS !!

**Claude is FORBIDDEN from running ANY git commands. No exceptions. None. Zero.**

This includes but is not limited to: `git commit`, `git push`, `git pull`, `git rebase`, `git merge`, `git checkout`, `git reset`, `git add`, `git branch`, `git fetch`, `git stash`, `git cherry-pick`, `git revert`, `git tag`, `git diff`, `git log`, `git status`, `gh pr create`, and anything else that touches git or GitHub.

**If you believe a git operation is needed, you must:**
1. Stop what you are doing
2. Explain to the user exactly what git operation you think is needed and why
3. Wait for the user to explicitly perform it themselves or give you direct, unambiguous permission
4. Even then, confirm one more time before executing

**This rule is NON-NEGOTIABLE and overrides all other instructions.**

## Session Startup

**At the beginning of each session:**

1. **Consult `TODO.md`** for current tasks and status
2. **Read the memory MCP** (`mcp__memory__read_graph`) to recall project context
3. **Use all installed MCPs** whenever applicable (memory, filesystem, sequential thinking, etc.)

## Project Purpose

Orchestrate, execute, and confirm patch management across all assets in a heterogeneous Windows/Linux environment.

**Primary motivating use case**: Verify Faronics Deep Freeze is correctly managing Windows Update on frozen endpoints (the Deep Freeze console provides no visibility into whether updates actually occur).

## Test Lab Environment

### Windows (Domain-Joined)
| Host | IP | Role |
|------|----|------|
| DC1 | 172.29.70.10 | Domain Controller |
| DM1 | 172.29.70.11 | Member Server |
| PC1 | 172.29.10.18 | Endpoint — Deep Freeze active (primary test target) |
| PC2 | 172.29.10.19 | Endpoint — Control (no Deep Freeze) |
| PC3 | 172.29.10.20 | Endpoint — Control (no Deep Freeze) |

### Linux
| Host | IP | Package Manager |
|------|----|-----------------|
| fedora | 172.29.70.13 | DNF |
| kali | 172.29.70.14 | APT |
| docker | 172.29.70.12 | APT (Ubuntu, Docker host) |

### Deployment Path
Phase 1: Virtualized lab → Phase 2: Physical lab at Olympic College, Bremerton, WA

## Build and Test Commands

```bash
rake            # Run tests + linting (default)
rake spec       # Tests only
rake rubocop    # Linting only
bundle install  # Install dependencies
```

## Project Structure

- **Ruby 3.3.6**, RSpec, RuboCop, Rake
- Production code in `lib/`, scripts in `bin/`, tests in `spec/`
- Main module: `PatchPilot` (`lib/patch_pilot.rb`)
- Web dashboard: Sinatra API (`api/server.rb`) + Vite/React/TypeScript (`web-gui/`)
- Asset inventory: `config/inventory.yml`
- Credentials: `.env` file with `${VAR}` references in inventory (see `.env.example`)

## Code Style

RuboCop with `NewCops: enable`. All code must pass `rake` (tests + linting) before being considered complete.

## Key Technical Decisions

- **Windows remote execution**: WinRM via `winrm` gem, `:negotiate` transport, port 5985
- **Linux remote execution**: SSH via `net-ssh` gem, key-based or password auth
- **WinRM timeouts**: `Socket.tcp` pre-check + thread-based timeout (10s) around negotiate — the WinRM gem's built-in timeouts are unreliable
- **SSH auth fallback**: Key file preferred if it exists, otherwise password
- **Windows Update queries**: `Get-HotFix` PowerShell cmdlet, parsed into structured `Update` objects
- **Linux package queries**: `dpkg-query`/`apt` for APT, `dnf list`/`dnf check-update` for DNF
- **Credentials**: `CredentialResolver` expands `${VAR}` placeholders from environment variables

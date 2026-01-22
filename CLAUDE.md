# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Test Commands

```bash
# Run all checks (tests + linting) - default task
rake

# Run only tests
rake spec

# Run only linting
rake rubocop

# Install dependencies
bundle install
```

## Project Structure

This is a Ruby library project using:
- **Ruby 3.3.6** (specified in `.ruby-version`)
- **RSpec** for testing (`spec/` directory)
- **RuboCop** for code style enforcement
- **Rake** for task automation

Production code goes in `lib/`, executable scripts in `bin/`.

## Code Style

RuboCop is configured with `NewCops: enable` - all new cops are automatically enabled. The default `rake` task runs both tests and linting, so all code must pass RuboCop before being considered complete.

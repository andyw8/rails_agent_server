# Testing

This document explains the test structure and how to run tests for the rails_agent_server gem.

## Test Structure

The test suite is organized into three categories:

### Unit Tests (Always Run)

- **`test/test_rails_agent_server.rb`** - Tests for the `Server` class
  - Path resolution and defaults
  - Server status checking
  - Response formatting
  - File cleanup
  - No actual process forking or Rails loading

- **`test/test_cli.rb`** - Tests for the `CLI` class
  - Command parsing and help text
  - Error handling
  - Mocked server interactions
  - No actual server startup

### Integration Tests (Manual Only)

- **`test/test_integration.rb`** - Tests with actual server process
  - Forks background server process
  - Tests real socket communication
  - Tests code execution and error handling
  - Requires ability to fork and manage processes

- **`test/test_dummy_integration.rb`** - Tests with dummy Rails app
  - Uses `test/dummy` Rails application
  - Tests full Rails environment loading
  - Tests database operations and persistence
  - Most realistic but slowest tests

## Running Tests

### Quick Test (Default)

Run the unit tests that are stable in all environments:

```bash
bundle exec rake test
```

This runs only the unit tests (`test_rails_agent_server.rb` and `test_cli.rb`).

### Run Linter

```bash
bundle exec rake standard
```

### Run Both Tests and Linter

```bash
bundle exec rake
```

### Run Integration Tests (Local Only)

These tests fork processes and require a real Rails environment:

```bash
# Run basic integration tests
bundle exec ruby -Ilib:test test/test_integration.rb

# Run Rails dummy app integration tests
cd test/dummy
bundle exec ruby -I../../lib:../../test ../../test/test_dummy_integration.rb
```

**Note:** Integration tests are skipped in CI because they:
- Fork background processes (flaky in GitHub Actions)
- Require full Rails boot (slow and environment-dependent)
- Test socket/TTY behavior (unreliable in containerized CI)

## CI Configuration

The CI workflow (`.github/workflows/main.yml`) runs:

1. `bundle exec rake test` - Unit tests only
2. `bundle exec rake standard` - Code linting

The Rakefile explicitly sets `test_globs` to only include unit tests, preventing integration tests from running automatically.

## Test Philosophy

- **Unit tests** should be fast, deterministic, and run everywhere (local, CI, different OS)
- **Integration tests** verify real-world behavior but may be environment-specific
- All tests use standard Minitest without extra dependencies

## Troubleshooting

### Tests hang or timeout

This usually means an integration test is running when it shouldn't be. Check:

1. Is `ENV['CI']` set? Integration tests skip when this is set.
2. Are you running the right test file? Use `bundle exec rake test` for safety.
3. Is there a stale server process? Run `ps aux | grep rails_agent_server` and kill if needed.

### Integration tests fail locally

Integration tests require:
- Ability to fork processes (won't work on Windows)
- Write access to temp directories
- No firewall blocking Unix sockets

If they fail, focus on unit tests which provide good coverage of the core functionality.

## Adding New Tests

- **Add unit tests** for new functionality in the Server or CLI classes
- **Keep mocks simple** - avoid calling test assertions inside mocked methods
- **Integration tests are optional** - they verify real behavior but aren't required for CI
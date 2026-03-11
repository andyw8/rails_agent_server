# Rails REPL Server

A persistent Rails REPL server that avoids boot overhead for repeated queries. Perfect for AI agents like Claude Code that need fast Rails console access without waiting for Rails to boot on every request.

## Why This Gem?

When using AI coding assistants or automation tools with Rails applications, you often need to run many small queries to understand the schema, query data, or test code. Using `bin/rails runner` for each query means booting Rails every time, which can take 5-10 seconds per query.

Rails REPL Server starts a persistent background server that keeps Rails loaded in memory. The first request takes the normal Rails boot time, but subsequent requests are instant.

### vs. Spring

Spring is Rails' official application preloader and is a viable alternative for this use case. However, some projects prefer to avoid Spring for various reasons:

- **Simplicity**: Spring can sometimes cause confusion with stale code or require manual intervention (`spring stop`)
- **Compatibility**: Some projects have experienced issues with Spring in certain environments or with specific gems
- **Control**: Rails REPL Server provides explicit start/stop commands and clear visibility into server status
- **CI/CD**: Many projects disable Spring in CI environments and prefer consistent behavior across all environments

If Spring works well for your project, you can use `bin/spring rails runner` instead. Rails REPL Server is for teams that prefer an alternative approach or have disabled Spring.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rails_repl_server', group: :development
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install rails_repl_server
```

## Usage

### Basic Commands

```bash
# Run a Ruby expression (auto-starts server if needed)
rails_repl 'User.count'

# Run code that prints output
rails_repl 'puts User.pluck(:email).join(", ")'

# Run a script file
rails_repl /path/to/script.rb

# Server management
rails_repl status                    # Check if server is running
rails_repl start                     # Manually start the server
rails_repl stop                      # Stop the background server
rails_repl restart                   # Restart the background server
rails_repl help                      # Show help
```

### Examples

```bash
# Database queries
rails_repl 'User.count'
rails_repl 'Post.where(published: true).pluck(:title)'
rails_repl 'User.find_by(email: "test@example.com")&.name'

# Inspect schema
rails_repl 'ActiveRecord::Base.connection.tables'
rails_repl 'User.column_names'

# Complex operations
rails_repl 'User.group(:status).count'
rails_repl 'Rails.cache.clear; "Cache cleared"'
```

## For AI Agents (Claude Code)

Add this section to your project's `CLAUDE.md` or `.github/prompts/rails.md`:

```markdown
## Rails Console Access

This project uses `rails_repl` for fast Rails console access without boot overhead.

When you need to query the database or run Rails code:
- Use `rails_repl 'YourCode.here'` instead of `bin/rails runner`
- First request auto-starts a persistent server (takes ~5 seconds)
- Subsequent requests are instant (no Rails boot time)
- Server stays running in background until you run `rails_repl stop`

Examples:
  rails_repl 'User.count'
  rails_repl 'Post.where(published: true).count'
  rails_repl 'User.find_by(email: "test@example.com")&.name'
```

## How It Works

1. **First Request**: When you run `rails_repl` for the first time, it:
   - Spawns a background server process
   - Loads your Rails environment once
   - Creates a Unix socket for communication
   - Stores the PID for management

2. **Subsequent Requests**: Each request:
   - Connects to the existing Unix socket
   - Sends code to execute
   - Receives the result instantly
   - No Rails boot time required

3. **Server Management**: The server:
   - Runs in the background until explicitly stopped
   - Captures both printed output and expression results
   - Handles errors gracefully
   - Cleans up socket and PID files on exit

## File Locations

By default, the server creates these files in your Rails application:

- **Socket**: `tmp/rails_repl.sock` - Unix socket for communication
- **PID file**: `tmp/pids/rails_repl.pid` - Process ID for management
- **Log file**: `log/rails_repl.log` - Server output and errors

If not in a Rails directory, files are created in `/tmp/`.

## Performance

- **First request**: ~5-10 seconds (Rails boot time)
- **Subsequent requests**: ~50-200ms (no boot overhead)
- **Memory**: One Rails process running in background (~200-500MB depending on your app)

## When to Restart

You should restart the server when:
- You've changed model files or schema
- You've updated initializers
- You've modified environment configuration
- The server is returning stale data

```bash
rails_repl restart
```

## Limitations

- Code is evaluated in the server's context, so some IRB-specific features won't work
- The server must be restarted to pick up code changes
- Only one server runs per Rails application (shared socket file)
- Requires Unix sockets (macOS, Linux, WSL)

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/andyw8/rails_repl_server.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Credits

Created by [Andy Waite](https://github.com/andyw8) to improve the experience of using AI coding assistants with Rails applications.
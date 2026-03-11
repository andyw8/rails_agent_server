# Rails Agent Server

A persistent Rails server for AI agents that avoids boot overhead for repeated queries. Intended for AI agents like Claude Code that need fast Rails console access without waiting for Rails to boot on every request.

## Why This Gem?

When using AI coding assistants or automation tools with Rails applications, the agent often needs to run many small queries to understand the runtime behaviour or state. Using `bin/rails runner` for each query means booting Rails every time, which can typically take 5-10 seconds per query.

Rails Agent Server starts a persistent background server that keeps Rails loaded in memory. The first request takes the normal Rails boot time, but subsequent requests are instant.

### Why Not `bin/rails console`?

AI agents can't easily interact with `bin/rails console` because:

- **Interactive TTY requirement**: Rails console expects an interactive terminal (TTY) and won't accept input from standard pipes
- **No request/response protocol**: There's no simple way to send a command and receive just its result back
- **Session complexity**: Managing an interactive console session requires handling readline, prompt detection, and terminal control sequences
- **Output parsing**: Console output includes prompts, formatting, and IRB metadata that's difficult to parse programmatically

Rails Agent Server provides a simple request/response interface over Unix sockets, making it trivial for AI agents to execute code and get clean results.

### vs. Spring

Spring is Rails' official application preloader and is a viable alternative for this use case. However, some projects prefer to avoid Spring for various reasons:

- **Simplicity**: Spring can sometimes cause confusion with stale code or require manual intervention (`spring stop`)
- **Compatibility**: Some projects have experienced issues with Spring in certain environments or with specific gems

If Spring works well for your project, you can use `bin/spring rails runner` instead. Rails Agent Server is for teams that prefer an alternative approach or have disabled Spring.

### vs. MCP (Model Context Protocol)

MCP servers provide a structured way for AI agents to interact with systems through defined tools and resources. While MCP is excellent for complex, multi-step workflows and standardized interfaces, Rails Agent Server is preferable when:

- **Simplicity**: You just need to run Rails code quickly without defining MCP tools and schemas
- **Flexibility**: AI agents can execute arbitrary Rails code without being limited to predefined tool operations
- **Setup**: No need to configure MCP server definitions, transport layers, or client-server communication
- **Performance**: Direct command execution is faster than MCP's request/response protocol overhead
- **Token efficiency**: MCP can consume many tokens for structured tool schemas and responses
- **Existing workflows**: Works with agents that already know how to run shell commands

Rails Agent Server is a lightweight alternative that lets AI agents treat your Rails app like a fast REPL, while MCP is better suited for building formalized integrations with specific capabilities.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rails_agent_server', group: :development
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install rails_agent_server
```

## Agent Setup

Add this section to your project's `CLAUDE.md` or equivalent:

```markdown
## Rails Console Access

This project uses `rails_agent_server` for fast Rails console access without boot overhead.

When you need to query the database or run Rails code:
- Use `rails_agent_server 'YourCode.here'` instead of `bin/rails runner`
- First request auto-starts a persistent server (takes ~5 seconds)
- Subsequent requests are instant (no Rails boot time)
- Server stays running in background until you run `rails_agent_server stop`

Examples:
  rails_agent_server 'User.count'
  rails_agent_server 'Post.where(published: true).count'
  rails_agent_server 'User.find_by(email: "test@example.com")&.name'
```

## Usage

### Basic Commands

These commands are designed to be used by AI agents (like Claude Code) or automation tools, and not intended for manual use.

```bash
# Run a Ruby expression (auto-starts server if needed)
rails_agent_server 'User.count'

# Run code that prints output
rails_agent_server 'puts User.pluck(:email).join(", ")'

# Run a script file
rails_agent_server /path/to/script.rb

# Server management
rails_agent_server status                    # Check if server is running
rails_agent_server start                     # Manually start the server
rails_agent_server stop                      # Stop the background server
rails_agent_server restart                   # Restart the background server
rails_agent_server help                      # Show help
```

### Examples

```bash
# Database queries
rails_agent_server 'User.count'
rails_agent_server 'Post.where(published: true).pluck(:title)'
rails_agent_server 'User.find_by(email: "test@example.com")&.name'

# Inspect schema
rails_agent_server 'ActiveRecord::Base.connection.tables'
rails_agent_server 'User.column_names'

# Complex operations
rails_agent_server 'User.group(:status).count'
rails_agent_server 'Rails.cache.clear; "Cache cleared"'
```

## How It Works

1. **First Request**: When you run `rails_agent` for the first time, it:
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

- **Socket**: `tmp/rails_agent.sock` - Unix socket for communication
- **PID file**: `tmp/pids/rails_agent.pid` - Process ID for management
- **Log file**: `log/rails_agent.log` - Server output and errors

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
rails_agent_server restart
```

## Limitations

- The server may need to be restarted to pick up some code changes
- Only one server runs per Rails application (shared socket file)
- Requires Unix sockets (macOS, Linux, WSL)

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/andyw8/rails_agent_server.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
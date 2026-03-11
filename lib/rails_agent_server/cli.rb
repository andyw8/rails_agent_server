# frozen_string_literal: true

require_relative "server"

module RailsAgentServer
  class CLI
    attr_reader :server

    def initialize(argv = ARGV)
      @argv = argv
      @server = Server.new
    end

    def run
      case @argv[0]
      when "stop"
        server.stop
      when "restart"
        server.restart
      when "status"
        server.status
      when "--help", "-h", nil
        print_help
      else
        execute_code
      end
    end

    private

    def execute_code
      code = if @argv[0] && File.exist?(@argv[0])
        File.read(@argv[0])
      else
        @argv.join(" ")
      end

      if code.empty?
        warn "Error: No code provided"
        print_help
        exit 1
      end

      begin
        puts server.execute(code)
      rescue Errno::ENOENT
        warn "Error: Could not connect to Rails agent server"
        exit 1
      rescue => e
        warn "Error: #{e.message}"
        exit 1
      end
    end

    def print_help
      puts <<~HELP
        Rails Agent Server - A persistent Rails server for AI agents

        Usage:
          rails_agent_server 'puts User.count'         # Run a Ruby expression
          rails_agent_server /path/to/script.rb        # Run a script file
          rails_agent_server stop                      # Stop the server
          rails_agent_server restart                   # Restart the server
          rails_agent_server status                    # Check server status

        The server auto-starts on first use if not already running.

        Examples:
          rails_agent_server 'puts User.count'
          rails_agent_server 'puts User.pluck(:email).join(", ")'
          rails_agent_server 'puts ActiveRecord::Base.connection.tables'
          rails_agent_server script.rb

        For Claude Code or AI agents, add this to your CLAUDE.md:

          ## Rails Console Access

          This project uses rails_agent_server for fast Rails console access without boot overhead.

          When you need to query the database or run Rails code:
          - Use `rails_agent_server 'YourCode.here'` instead of `bin/rails runner`
          - First request auto-starts a persistent server (takes ~5 seconds)
          - Subsequent requests are instant (no Rails boot time)
          - Server stays running in background until you run `rails_agent_server stop`

          Examples:
            rails_agent_server 'puts User.count'
            rails_agent_server 'puts Post.where(published: true).count'
            rails_agent_server 'puts User.find_by(email: "test@example.com")&.name'
      HELP
    end
  end
end

# frozen_string_literal: true

require_relative "server"

module RailsReplServer
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
      when "start"
        server.start
        puts "Rails REPL server started"
      when "--help", "-h", "help", nil
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
        $stderr.puts "Error: No code provided"
        print_help
        exit 1
      end

      begin
        puts server.execute(code)
      rescue Errno::ENOENT
        $stderr.puts "Error: Could not connect to Rails REPL server"
        exit 1
      rescue => e
        $stderr.puts "Error: #{e.message}"
        exit 1
      end
    end

    def print_help
      puts <<~HELP
        Rails REPL Server - A persistent Rails REPL that avoids boot overhead

        Usage:
          rails_repl 'User.count'              # Run a Ruby expression
          rails_repl /path/to/script.rb        # Run a script file
          rails_repl start                     # Start the server
          rails_repl stop                      # Stop the server
          rails_repl restart                   # Restart the server
          rails_repl status                    # Check server status
          rails_repl help                      # Show this help

        The server auto-starts on first use if not already running.

        Examples:
          rails_repl 'User.count'
          rails_repl 'puts User.pluck(:email).join(", ")'
          rails_repl 'ActiveRecord::Base.connection.tables'
          rails_repl script.rb

        For Claude Code or AI agents, add this to your CLAUDE.md:

          ## Rails Console Access

          This project uses rails_repl for fast Rails console access without boot overhead.

          When you need to query the database or run Rails code:
          - Use `rails_repl 'YourCode.here'` instead of `bin/rails runner`
          - First request auto-starts a persistent server (takes ~5 seconds)
          - Subsequent requests are instant (no Rails boot time)
          - Server stays running in background until you run `rails_repl stop`

          Examples:
            rails_repl 'User.count'
            rails_repl 'Post.where(published: true).count'
            rails_repl 'User.find_by(email: "test@example.com")&.name'
      HELP
    end
  end
end

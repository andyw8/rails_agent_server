# frozen_string_literal: true

require "socket"
require "fileutils"
require "stringio"

module RailsAgentServer
  class Server
    attr_reader :socket_path, :pid_path, :log_path

    def initialize(socket_path: nil, pid_path: nil, log_path: nil)
      @socket_path = socket_path || default_socket_path
      @pid_path = pid_path || default_pid_path
      @log_path = log_path || default_log_path
    end

    def start
      return if running?

      puts "Starting Rails agent server (this will take a few seconds)..."

      # Build load path argument to ensure spawned process uses same gem version
      load_path_args = $LOAD_PATH.map { |path| ["-I", path] }.flatten

      pid = spawn(
        RbConfig.ruby, *load_path_args, "-r", "rails_agent_server/server",
        "-e", "RailsAgentServer::Server.new(socket_path: '#{socket_path}', pid_path: '#{pid_path}', log_path: '#{log_path}').run",
        out: log_path, err: log_path
      )
      Process.detach(pid)

      wait_for_server(pid)
    end

    def stop
      if File.exist?(pid_path)
        pid = File.read(pid_path).strip.to_i
        begin
          Process.kill("TERM", pid)
          puts "Stopped Rails agent server (PID: #{pid})"
        rescue Errno::ESRCH
          puts "Rails agent server is not running (stale PID file)"
          cleanup_files
        end
      else
        puts "Rails agent server is not running"
      end
    end

    def restart
      stop if running?
      cleanup_files
      sleep 0.5
      start
      puts "Rails agent server restarted"
    end

    def status
      if running?
        pid = File.read(pid_path).strip
        puts "Rails agent server is running (PID: #{pid})"
        true
      else
        puts "Rails agent server is not running"
        false
      end
    end

    def running?
      return false unless File.exist?(pid_path)

      pid = File.read(pid_path).strip.to_i
      Process.kill(0, pid)
      true
    rescue Errno::ESRCH, Errno::EPERM
      false
    end

    def run
      load_rails_environment

      FileUtils.rm_f(socket_path)
      server = UNIXServer.new(socket_path)
      File.write(pid_path, Process.pid.to_s)

      $stdout.puts "Rails agent server listening on #{socket_path} (PID: #{Process.pid})"

      setup_signal_handlers
      at_exit { cleanup_files }

      loop do
        client = server.accept
        handle_client(client)
      end
    rescue => e
      warn "Server error: #{e.class}: #{e.message}"
      warn e.backtrace.join("\n")
      cleanup_files
      raise
    end

    def execute(code)
      start unless running?

      socket = UNIXSocket.new(socket_path)
      socket.write(code)
      socket.close_write
      response = socket.read
      socket.close
      response
    end

    private

    def default_socket_path
      if defined?(Rails) && Rails.root
        Rails.root.join("tmp", "rails_agent_server.sock").to_s
      else
        "/tmp/rails_agent_server.sock"
      end
    end

    def default_pid_path
      if defined?(Rails) && Rails.root
        Rails.root.join("tmp", "pids", "rails_agent_server.pid").to_s
      else
        "/tmp/rails_agent_server.pid"
      end
    end

    def default_log_path
      if defined?(Rails) && Rails.root
        Rails.root.join("log", "rails_agent_server.log").to_s
      else
        "/tmp/rails_agent_server.log"
      end
    end

    def wait_for_server(pid, timeout: 30)
      (timeout * 2).times do
        return if File.exist?(socket_path)

        # Check if process is still alive
        begin
          Process.kill(0, pid)
        rescue Errno::ESRCH
          # Process died - show error from log
          if File.exist?(log_path)
            error_msg = File.read(log_path).strip
            abort "Rails agent server failed to start: #{error_msg}"
          else
            abort "Rails agent server failed to start (no log file found)"
          end
        end

        sleep 0.5
      end

      abort "Timed out waiting for Rails agent server to start. Check #{log_path}"
    end

    def cleanup_files
      FileUtils.rm_f(socket_path)
      FileUtils.rm_f(pid_path)
    end

    def setup_signal_handlers
      trap("INT") { exit }
      trap("TERM") { exit }
    end

    def load_rails_environment
      return if defined?(Rails)

      rails_root = find_rails_root
      abort "Not in a Rails application directory" unless rails_root

      environment_path = File.join(rails_root, "config", "environment.rb")
      abort "Rails environment not found at #{environment_path}" unless File.exist?(environment_path)

      # Ensure tmp/pids directory exists
      FileUtils.mkdir_p(File.dirname(pid_path))

      require environment_path
    end

    def find_rails_root
      current_dir = Dir.pwd
      until current_dir == "/"
        config_path = File.join(current_dir, "config", "environment.rb")
        return current_dir if File.exist?(config_path)
        current_dir = File.dirname(current_dir)
      end
      nil
    end

    def handle_client(client)
      code = client.read

      output = StringIO.new
      result = nil
      error = nil

      begin
        old_stdout = $stdout
        $stdout = output
        result = eval(code, TOPLEVEL_BINDING) # rubocop:disable Security/Eval
        $stdout = old_stdout
      rescue => e
        $stdout = old_stdout
        error = format_error(e)
      end

      response = build_response(output.string, result, error)
      client.write(response)
      client.close
    rescue => e
      client.write("Server error: #{e.class}: #{e.message}")
      client.close
    end

    def format_error(exception)
      message = "#{exception.class}: #{exception.message}"
      if exception.backtrace
        backtrace = exception.backtrace.first(5).join("\n  ")
        message += "\n  #{backtrace}"
      end
      message
    end

    def build_response(printed_output, result, error)
      response = +""
      response << printed_output unless printed_output.empty?

      if error
        response << error
      end

      response
    end
  end
end

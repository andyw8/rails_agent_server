# frozen_string_literal: true

require "socket"
require "fileutils"
require "stringio"

module RailsReplServer
  class Server
    attr_reader :socket_path, :pid_path, :log_path

    def initialize(socket_path: nil, pid_path: nil, log_path: nil)
      @socket_path = socket_path || default_socket_path
      @pid_path = pid_path || default_pid_path
      @log_path = log_path || default_log_path
    end

    def start
      return if running?

      puts "Starting Rails REPL server (this will take a few seconds)..."

      pid = spawn(
        RbConfig.ruby, "-r", "rails_repl_server/server",
        "-e", "RailsReplServer::Server.new(socket_path: '#{socket_path}', pid_path: '#{pid_path}', log_path: '#{log_path}').run",
        out: log_path, err: log_path
      )
      Process.detach(pid)

      wait_for_server
    end

    def stop
      if File.exist?(pid_path)
        pid = File.read(pid_path).strip.to_i
        begin
          Process.kill("TERM", pid)
          puts "Stopped Rails REPL server (PID: #{pid})"
        rescue Errno::ESRCH
          puts "Rails REPL server is not running (stale PID file)"
          cleanup_files
        end
      else
        puts "Rails REPL server is not running"
      end
    end

    def restart
      stop if running?
      cleanup_files
      sleep 0.5
      start
      puts "Rails REPL server restarted"
    end

    def status
      if running?
        pid = File.read(pid_path).strip
        puts "Rails REPL server is running (PID: #{pid})"
        true
      else
        puts "Rails REPL server is not running"
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

      $stdout.puts "Rails REPL server listening on #{socket_path} (PID: #{Process.pid})"

      setup_signal_handlers
      at_exit { cleanup_files }

      loop do
        client = server.accept
        handle_client(client)
      end
    rescue => e
      $stderr.puts "Server error: #{e.class}: #{e.message}"
      $stderr.puts e.backtrace.join("\n")
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
        Rails.root.join("tmp", "rails_repl.sock").to_s
      else
        "/tmp/rails_repl.sock"
      end
    end

    def default_pid_path
      if defined?(Rails) && Rails.root
        Rails.root.join("tmp", "pids", "rails_repl.pid").to_s
      else
        "/tmp/rails_repl.pid"
      end
    end

    def default_log_path
      if defined?(Rails) && Rails.root
        Rails.root.join("log", "rails_repl.log").to_s
      else
        "/tmp/rails_repl.log"
      end
    end

    def wait_for_server(timeout: 30)
      (timeout * 2).times do
        return if File.exist?(socket_path)
        sleep 0.5
      end

      abort "Timed out waiting for Rails REPL server to start. Check #{log_path}"
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
      elsif printed_output.empty?
        response << result.inspect
      end

      response
    end
  end
end

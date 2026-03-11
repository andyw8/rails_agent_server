# frozen_string_literal: true

require "test_helper"
require "tempfile"
require "fileutils"
require "stringio"

class TestCLI < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir
    @socket_path = File.join(@temp_dir, "test_rails_agent.sock")
    @pid_path = File.join(@temp_dir, "test_rails_agent.pid")
    @log_path = File.join(@temp_dir, "test_rails_agent.log")

    @original_stdout = $stdout
    @original_stderr = $stderr
    $stdout = StringIO.new
    $stderr = StringIO.new
  end

  def teardown
    $stdout = @original_stdout
    $stderr = @original_stderr

    FileUtils.rm_rf(@temp_dir) if @temp_dir && File.exist?(@temp_dir)
  end

  def test_dash_h_shows_help
    cli = RailsAgentServer::CLI.new(["-h"])
    cli.run

    output = $stdout.string
    assert_includes output, "Rails Agent Server"
  end

  def test_dash_dash_help_shows_help
    cli = RailsAgentServer::CLI.new(["--help"])
    cli.run

    output = $stdout.string
    assert_includes output, "Rails Agent Server"
  end

  def test_no_arguments_shows_help
    cli = RailsAgentServer::CLI.new([])
    cli.run

    output = $stdout.string
    assert_includes output, "Rails Agent Server"
  end

  def test_status_command_when_not_running
    cli = RailsAgentServer::CLI.new(["status"])
    server = RailsAgentServer::Server.new(
      socket_path: @socket_path,
      pid_path: @pid_path,
      log_path: @log_path
    )
    cli.instance_variable_set(:@server, server)

    cli.run

    output = $stdout.string
    assert_includes output, "not running"
  end

  def test_stop_command_when_not_running
    cli = RailsAgentServer::CLI.new(["stop"])
    server = RailsAgentServer::Server.new(
      socket_path: @socket_path,
      pid_path: @pid_path,
      log_path: @log_path
    )
    cli.instance_variable_set(:@server, server)

    cli.run

    output = $stdout.string
    assert_includes output, "not running"
  end

  def test_empty_code_shows_error_and_help
    cli = RailsAgentServer::CLI.new([""])

    exit_code = nil
    begin
      cli.run
    rescue SystemExit => e
      exit_code = e.status
    end

    assert_equal 1, exit_code
    error_output = $stderr.string
    assert_includes error_output, "No code provided"

    help_output = $stdout.string
    assert_includes help_output, "Usage:"
  end

  def test_cli_initializes_with_default_server
    cli = RailsAgentServer::CLI.new([])
    assert_kind_of RailsAgentServer::Server, cli.server
  end

  def test_start_command
    cli = RailsAgentServer::CLI.new(["start"])
    server = RailsAgentServer::Server.new(
      socket_path: @socket_path,
      pid_path: @pid_path,
      log_path: @log_path
    )
    cli.instance_variable_set(:@server, server)

    # Mock the server.start method to avoid actually starting
    def server.start
      # Do nothing
    end

    cli.run

    output = $stdout.string
    assert_includes output, "started"
  end

  def test_help_includes_examples
    cli = RailsAgentServer::CLI.new(["--help"])
    cli.run

    output = $stdout.string
    assert_includes output, "Examples:"
    assert_includes output, "User.count"
    assert_includes output, "CLAUDE.md"
  end

  def test_help_includes_all_commands
    cli = RailsAgentServer::CLI.new(["--help"])
    cli.run

    output = $stdout.string
    assert_includes output, "start"
    assert_includes output, "stop"
    assert_includes output, "restart"
    assert_includes output, "status"
  end

  def test_execute_code_with_file
    # Create a temporary script file
    script_file = File.join(@temp_dir, "test_script.rb")
    File.write(script_file, "puts 'Hello from script'")

    cli = RailsAgentServer::CLI.new([script_file])
    server = RailsAgentServer::Server.new(
      socket_path: @socket_path,
      pid_path: @pid_path,
      log_path: @log_path
    )
    cli.instance_variable_set(:@server, server)

    # Mock the server.execute method
    def server.execute(code)
      "Hello from script\n"
    end

    cli.run

    output = $stdout.string
    assert_includes output, "Hello from script"
  end

  def test_execute_code_with_string
    cli = RailsAgentServer::CLI.new(["1", "+", "1"])
    server = RailsAgentServer::Server.new(
      socket_path: @socket_path,
      pid_path: @pid_path,
      log_path: @log_path
    )
    cli.instance_variable_set(:@server, server)

    # Mock the server.execute method
    def server.execute(code)
      "2"
    end

    cli.run

    output = $stdout.string
    assert_includes output, "2"
  end

  def test_connection_error_handling
    cli = RailsAgentServer::CLI.new(["User.count"])
    server = RailsAgentServer::Server.new(
      socket_path: @socket_path,
      pid_path: @pid_path,
      log_path: @log_path
    )
    cli.instance_variable_set(:@server, server)

    # Mock the server.execute method to raise connection error
    def server.execute(code)
      raise Errno::ENOENT, "No such file or directory"
    end

    exit_code = nil
    begin
      cli.run
    rescue SystemExit => e
      exit_code = e.status
    end

    assert_equal 1, exit_code
    error_output = $stderr.string
    assert_includes error_output, "Could not connect"
  end

  def test_generic_error_handling
    cli = RailsAgentServer::CLI.new(["User.count"])
    server = RailsAgentServer::Server.new(
      socket_path: @socket_path,
      pid_path: @pid_path,
      log_path: @log_path
    )
    cli.instance_variable_set(:@server, server)

    # Mock the server.execute method to raise generic error
    def server.execute(code)
      raise StandardError, "Something went wrong"
    end

    exit_code = nil
    begin
      cli.run
    rescue SystemExit => e
      exit_code = e.status
    end

    assert_equal 1, exit_code
    error_output = $stderr.string
    assert_includes error_output, "Something went wrong"
  end
end

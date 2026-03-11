# frozen_string_literal: true

require "test_helper"
require "tempfile"
require "fileutils"
require "socket"

class TestIntegration < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir
    @socket_path = File.join(@temp_dir, "test_rails_agent.sock")
    @pid_path = File.join(@temp_dir, "test_rails_agent.pid")
    @log_path = File.join(@temp_dir, "test_rails_agent.log")

    @server = RailsAgentServer::Server.new(
      socket_path: @socket_path,
      pid_path: @pid_path,
      log_path: @log_path
    )
  end

  def teardown
    # Clean up any running server
    if @server.running?
      @server.stop
      sleep 0.2
    end

    FileUtils.rm_rf(@temp_dir) if @temp_dir && File.exist?(@temp_dir)
  end

  def test_server_can_start_in_background
    skip "Requires Rails environment" unless defined?(Rails)

    pid = fork do
      @server.run
    end

    # Wait for server to be ready
    30.times do
      break if File.exist?(@socket_path)
      sleep 0.1
    end

    assert File.exist?(@socket_path), "Socket file should exist"
    assert File.exist?(@pid_path), "PID file should exist"
    assert @server.running?, "Server should be running"

    # Clean up
    Process.kill("TERM", pid)
    Process.wait(pid)
  end

  def test_execute_simple_expression
    skip "Requires Rails environment or mock" unless can_run_integration_test?

    # Start server in background
    start_mock_server

    result = @server.execute("1 + 1")
    assert_equal "2", result.strip
  end

  def test_execute_code_with_output
    skip "Requires Rails environment or mock" unless can_run_integration_test?

    start_mock_server

    result = @server.execute("puts 'Hello, World!'")
    assert_includes result, "Hello, World!"
  end

  def test_execute_code_with_error
    skip "Requires Rails environment or mock" unless can_run_integration_test?

    start_mock_server

    result = @server.execute("raise 'Test error'")
    assert_includes result, "RuntimeError"
    assert_includes result, "Test error"
  end

  def test_execute_multiple_requests
    skip "Requires Rails environment or mock" unless can_run_integration_test?

    start_mock_server

    result1 = @server.execute("1 + 1")
    assert_equal "2", result1.strip

    result2 = @server.execute("2 + 2")
    assert_equal "4", result2.strip

    result3 = @server.execute("3 + 3")
    assert_equal "6", result3.strip
  end

  def test_server_status_after_start
    skip "Requires Rails environment or mock" unless can_run_integration_test?

    refute @server.running?

    start_mock_server

    assert @server.running?
  end

  def test_server_stop
    skip "Requires Rails environment or mock" unless can_run_integration_test?

    start_mock_server
    assert @server.running?

    @server.stop
    sleep 0.2

    refute @server.running?
    refute File.exist?(@socket_path)
  end

  def test_server_restart
    skip "Requires Rails environment or mock" unless can_run_integration_test?

    start_mock_server
    assert @server.running?

    old_pid = File.read(@pid_path).to_i

    @server.restart
    sleep 0.5

    assert @server.running?
    new_pid = File.read(@pid_path).to_i
    refute_equal old_pid, new_pid, "PID should change after restart"
  end

  def test_execute_with_variable_assignment
    skip "Requires Rails environment or mock" unless can_run_integration_test?

    start_mock_server

    result1 = @server.execute("@test_var = 42")
    assert_equal "42", result1.strip

    result2 = @server.execute("@test_var")
    assert_equal "42", result2.strip
  end

  def test_execute_multiline_code
    skip "Requires Rails environment or mock" unless can_run_integration_test?

    start_mock_server

    code = <<~RUBY
      x = 10
      y = 20
      x + y
    RUBY

    result = @server.execute(code)
    assert_equal "30", result.strip
  end

  def test_execute_code_with_output_and_result
    skip "Requires Rails environment or mock" unless can_run_integration_test?

    start_mock_server

    code = <<~RUBY
      puts "Debug output"
      42
    RUBY

    result = @server.execute(code)
    # When there's printed output, it takes precedence
    assert_includes result, "Debug output"
  end

  private

  def can_run_integration_test?
    # Only run integration tests if we're in a test environment
    # that supports forking and basic Ruby eval
    RUBY_PLATFORM !~ /mswin|mingw/
  end

  def start_mock_server
    # Start a simple mock server that evaluates Ruby code
    # This doesn't require Rails, just Ruby eval
    pid = fork do
      # Close inherited file descriptors
      STDIN.close
      STDOUT.reopen(@log_path, "a")
      STDERR.reopen(@log_path, "a")

      FileUtils.rm_f(@socket_path)
      server = UNIXServer.new(@socket_path)
      File.write(@pid_path, Process.pid.to_s)

      trap("TERM") { exit }
      trap("INT") { exit }

      at_exit do
        FileUtils.rm_f(@socket_path)
        FileUtils.rm_f(@pid_path)
      end

      loop do
        client = server.accept
        code = client.read

        output = StringIO.new
        result = nil
        error = nil

        begin
          old_stdout = $stdout
          $stdout = output
          result = eval(code, TOPLEVEL_BINDING)
          $stdout = old_stdout
        rescue => e
          $stdout = old_stdout
          error = "#{e.class}: #{e.message}"
        end

        printed = output.string
        response = +""
        response << printed unless printed.empty?

        if error
          response << error
        elsif printed.empty?
          response << result.inspect
        end

        client.write(response)
        client.close
      end
    end

    Process.detach(pid)

    # Wait for server to be ready
    30.times do
      break if File.exist?(@socket_path)
      sleep 0.1
    end

    raise "Server failed to start" unless File.exist?(@socket_path)
  end
end

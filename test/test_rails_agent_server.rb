# frozen_string_literal: true

require "test_helper"
require "tempfile"
require "fileutils"

class TestRailsAgentServer < Minitest::Test
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
      sleep 0.1
    end

    FileUtils.rm_rf(@temp_dir) if @temp_dir && File.exist?(@temp_dir)
  end

  def test_that_it_has_a_version_number
    refute_nil ::RailsAgentServer::VERSION
  end

  def test_server_initialization
    assert_equal @socket_path, @server.socket_path
    assert_equal @pid_path, @server.pid_path
    assert_equal @log_path, @server.log_path
  end

  def test_server_not_running_initially
    refute @server.running?
  end

  def test_server_status_when_not_running
    refute @server.status
  end

  def test_default_paths_when_not_in_rails
    server = RailsAgentServer::Server.new
    assert_equal "/tmp/rails_agent.sock", server.socket_path
    assert_equal "/tmp/rails_agent.pid", server.pid_path
    assert_equal "/tmp/rails_agent.log", server.log_path
  end

  def test_running_returns_false_with_stale_pid_file
    # Create a stale PID file
    File.write(@pid_path, "999999")
    refute @server.running?
  end

  def test_stop_with_no_server_running
    # Should not raise an error
    @server.stop
  end

  def test_stop_with_stale_pid_file
    # Create a stale PID file with non-existent PID
    File.write(@pid_path, "999999")
    @server.stop
    refute File.exist?(@pid_path)
  end

  def test_format_error_includes_class_and_message
    server = @server
    error = StandardError.new("test error")
    formatted = server.send(:format_error, error)
    assert_includes formatted, "StandardError"
    assert_includes formatted, "test error"
  end

  def test_format_error_includes_backtrace
    server = @server
    begin
      raise StandardError, "test error"
    rescue => e
      formatted = server.send(:format_error, e)
      assert_includes formatted, "StandardError"
      assert_includes formatted, "test error"
      # Backtrace should be included
      assert_match(/test_rails_agent_server\.rb/, formatted)
    end
  end

  def test_build_response_with_result_only
    server = @server
    response = server.send(:build_response, "", 42, nil)
    assert_equal "42", response
  end

  def test_build_response_with_printed_output_only
    server = @server
    response = server.send(:build_response, "Hello\n", nil, nil)
    assert_equal "Hello\n", response
  end

  def test_build_response_with_printed_output_and_result
    server = @server
    response = server.send(:build_response, "Hello\n", 42, nil)
    assert_equal "Hello\n", response
  end

  def test_build_response_with_error
    server = @server
    response = server.send(:build_response, "", nil, "Error: test")
    assert_equal "Error: test", response
  end

  def test_build_response_with_printed_output_and_error
    server = @server
    response = server.send(:build_response, "Debug\n", nil, "Error: test")
    assert_equal "Debug\nError: test", response
  end

  def test_find_rails_root_returns_nil_when_not_in_rails
    server = @server
    # Save current dir
    original_dir = Dir.pwd

    begin
      # Change to a non-Rails directory
      Dir.chdir(@temp_dir)
      rails_root = server.send(:find_rails_root)
      assert_nil rails_root
    ensure
      Dir.chdir(original_dir)
    end
  end

  def test_cleanup_files_removes_socket_and_pid
    # Create dummy files
    FileUtils.touch(@socket_path)
    FileUtils.touch(@pid_path)

    @server.send(:cleanup_files)

    refute File.exist?(@socket_path)
    refute File.exist?(@pid_path)
  end

  def test_default_socket_path_uses_rails_root_when_available
    # Mock Rails constant
    rails_module = Module.new do
      def self.root
        Pathname.new("/fake/rails/root")
      end
    end

    Object.const_set(:Rails, rails_module)

    begin
      server = RailsAgentServer::Server.new
      assert_equal "/fake/rails/root/tmp/rails_agent.sock", server.socket_path
    ensure
      Object.send(:remove_const, :Rails)
    end
  end

  def test_default_pid_path_uses_rails_root_when_available
    # Mock Rails constant
    rails_module = Module.new do
      def self.root
        Pathname.new("/fake/rails/root")
      end
    end

    Object.const_set(:Rails, rails_module)

    begin
      server = RailsAgentServer::Server.new
      assert_equal "/fake/rails/root/tmp/pids/rails_agent.pid", server.pid_path
    ensure
      Object.send(:remove_const, :Rails)
    end
  end

  def test_default_log_path_uses_rails_root_when_available
    # Mock Rails constant
    rails_module = Module.new do
      def self.root
        Pathname.new("/fake/rails/root")
      end
    end

    Object.const_set(:Rails, rails_module)

    begin
      server = RailsAgentServer::Server.new
      assert_equal "/fake/rails/root/log/rails_agent.log", server.log_path
    ensure
      Object.send(:remove_const, :Rails)
    end
  end
end

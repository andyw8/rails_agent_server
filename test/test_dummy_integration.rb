# frozen_string_literal: true

require "test_helper"
require "fileutils"

class TestDummyIntegration < Minitest::Test
  def setup
    skip "Skipping slow dummy integration tests in CI" if ENV['CI']
    @dummy_path = File.expand_path("../test/dummy", __dir__)
    @rails_agent_server = File.expand_path("../exe/rails_agent_server", __dir__)

    # Ensure we're in the dummy app directory
    Dir.chdir(@dummy_path)

    # Stop any existing server
    system("bundle exec #{@rails_agent_server} stop > /dev/null 2>&1")
    sleep 0.2

    # Clean database
    system("bundle exec rails db:reset > /dev/null 2>&1")
  end

  def teardown
    # Clean up server
    system("bundle exec #{@rails_agent_server} stop > /dev/null 2>&1")
    sleep 0.2
  end

  def test_server_starts_and_executes_simple_query
    result = `bundle exec #{@rails_agent_server} 'User.count' 2>&1`.strip
    # Remove startup message if present
    result = result.split("\n").last
    assert_equal "0", result
  end

  def test_server_creates_record
    result = `bundle exec #{@rails_agent_server} 'User.create!(name: "Test", email: "test@example.com"); User.count' 2>&1`.strip
    result = result.split("\n").last
    assert_equal "1", result
  end

  def test_server_persists_data_across_requests
    # Create a user
    `bundle exec #{@rails_agent_server} 'User.create!(name: "Alice", email: "alice@example.com")' 2>&1`

    # Query in a separate request
    count = `bundle exec #{@rails_agent_server} 'User.count' 2>&1`.strip
    count = count.split("\n").last
    assert_equal "1", count

    # Query specific user
    result = `bundle exec #{@rails_agent_server} 'User.first.name' 2>&1`.strip
    result = result.split("\n").last
    assert_equal '"Alice"', result
  end

  def test_server_status_command
    # Start server by running a query
    `bundle exec #{@rails_agent_server} 'User.count'`

    # Check status
    result = `bundle exec #{@rails_agent_server} status`
    assert_includes result, "running"
    assert_includes result, "PID:"
  end

  def test_server_stop_command
    # Start server
    `bundle exec #{@rails_agent_server} 'User.count'`

    # Stop server
    result = `bundle exec #{@rails_agent_server} stop`
    assert_includes result, "Stopped"
  end

  def test_server_restart_command
    # Start server
    `bundle exec #{@rails_agent_server} 'User.count'`

    # Restart server
    result = `bundle exec #{@rails_agent_server} restart`
    assert_includes result, "restarted"
  end

  def test_server_handles_syntax_errors
    result = `bundle exec #{@rails_agent_server} 'User.invalid_method'`
    assert_includes result, "NoMethodError"
  end

  def test_server_handles_printed_output
    result = `bundle exec #{@rails_agent_server} 'puts "Hello, World!"' 2>&1`.strip
    result = result.split("\n").last
    assert_equal "Hello, World!", result
  end

  def test_server_handles_multiple_statements
    code = <<~RUBY
      x = 5
      y = 10
      x + y
    RUBY

    result = `bundle exec #{@rails_agent_server} '#{code.gsub("\n", "; ")}' 2>&1`.strip
    result = result.split("\n").last
    assert_equal "15", result
  end

  def test_server_can_query_rails_environment
    result = `bundle exec #{@rails_agent_server} 'Rails.env'`.strip
    assert_includes result, "development"
  end

  def test_server_can_query_database_tables
    result = `bundle exec #{@rails_agent_server} 'ActiveRecord::Base.connection.tables'`
    assert_includes result, "users"
  end

  def test_server_can_query_model_columns
    result = `bundle exec #{@rails_agent_server} 'User.column_names'`
    assert_includes result, "name"
    assert_includes result, "email"
  end

  def test_concurrent_requests
    # Start server
    `bundle exec #{@rails_agent_server} 'User.count'`

    # Run multiple requests
    results = 3.times.map do |i|
      Thread.new do
        `bundle exec #{@rails_agent_server} '#{i + 1} * 2'`.strip
      end
    end.map(&:value)

    assert_equal ["2", "4", "6"], results.sort
  end
end

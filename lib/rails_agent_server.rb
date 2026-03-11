# frozen_string_literal: true

require_relative "rails_agent_server/version"
require_relative "rails_agent_server/server"
require_relative "rails_agent_server/cli"

module RailsAgentServer
  class Error < StandardError; end
end

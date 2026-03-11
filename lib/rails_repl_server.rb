# frozen_string_literal: true

require_relative "rails_repl_server/version"
require_relative "rails_repl_server/server"
require_relative "rails_repl_server/cli"

module RailsReplServer
  class Error < StandardError; end
end

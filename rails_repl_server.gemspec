# frozen_string_literal: true

require_relative "lib/rails_repl_server/version"

Gem::Specification.new do |spec|
  spec.name = "rails_repl_server"
  spec.version = RailsReplServer::VERSION
  spec.authors = ["Andy Waite"]
  spec.email = ["andyw8@users.noreply.github.com"]

  spec.summary = "A persistent Rails REPL server that avoids boot overhead for repeated queries"
  spec.description = "Rails REPL Server provides a persistent background server for running Rails code without the overhead of booting Rails for each request. Perfect for AI agents and automation tools that need fast Rails console access."
  spec.homepage = "https://github.com/andyw8/rails_repl_server"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/andyw8/rails_repl_server"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore test/ .github/ .standard.yml spec.txt])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # No runtime dependencies - works with any Rails application

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end

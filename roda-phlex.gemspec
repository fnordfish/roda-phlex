# frozen_string_literal: true

require_relative "lib/roda/phlex"

Gem::Specification.new do |spec|
  spec.name = "roda-phlex"
  spec.version = Roda::RodaPlugins::Phlex::VERSION
  spec.authors = ["Robert Schulze"]
  spec.email = ["robert@dotless.de"]

  spec.summary = "A Phlex adapter for Roda"
  spec.description = "A Phlex adapter for Roda"
  spec.homepage = "https://github.com/fnordfish/roda-phlex"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "phlex", ">= 1.7.0"
  spec.add_dependency "roda", ">= 3.0.0"
end

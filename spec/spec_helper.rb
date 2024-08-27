# frozen_string_literal: true

require "phlex"
require "roda/phlex"
require "roda"

require "capybara/rspec"
require "rack/test"

require_relative "support/test_app_helper"
require_relative "support/capybara_helper"

RSpec.configure do |config|
  config.include Rack::Test::Methods
  config.include TestAppHelper
  config.include CapybaraHelper, type: :feature

  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  if config.files_to_run.one?
    # Use the documentation formatter for detailed output,
    # unless a formatter has already been configured
    # (e.g. via a command-line flag).
    config.default_formatter = "doc"
  end

  config.order = :random
  Kernel.srand(config.seed)
end

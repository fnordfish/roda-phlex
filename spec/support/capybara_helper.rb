# frozen_string_literal: true

module CapybaraHelper
  def get_capybara(path)
    Net::HTTP.start(
      Capybara.current_session.server.host,
      Capybara.current_session.server.port
    ) { |http|
      http.set_debug_output $stderr
      http.get(path)
    }
  end

  # Trick Capybara into managing Puma for us.
  class NeedsServerDriver < Capybara::Driver::Base
    def needs_server?
      true
    end
  end

  Capybara.register_driver(:needs_server) { NeedsServerDriver.new }
  Capybara.app = TestAppHelper.build_test_app(phlex: {}, streaming: {})
  Capybara.default_driver = :needs_server
  Capybara.server = :puma, {Silent: true}
end

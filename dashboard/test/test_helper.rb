ENV["RAILS_ENV"] ||= "test"
ENV["DASHBOARD_API_KEY"] ||= "test-api-key"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...

    def api_headers
      {"Authorization" => "Bearer test-api-key", "Content-Type" => "application/json"}
    end
  end
end

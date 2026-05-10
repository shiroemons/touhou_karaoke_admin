ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
    def assert_policy_permits(policy, *actions)
      actions.each do |action|
        assert policy.public_send(action), "Expected #{policy.class} to permit #{action}"
      end
    end

    def assert_policy_forbids(policy, *actions)
      actions.each do |action|
        assert_not policy.public_send(action), "Expected #{policy.class} to forbid #{action}"
      end
    end

    def assert_scope_resolves_all(scope_class)
      records = [Object.new]
      scope = Object.new
      scope.define_singleton_method(:all) { records }

      assert_same records, scope_class.new(nil, scope).resolve
    end
  end
end

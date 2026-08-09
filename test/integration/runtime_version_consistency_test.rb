require 'test_helper'
require 'yaml'

class RuntimeVersionConsistencyTest < ActiveSupport::TestCase
  test 'CI and Docker Compose use the same PostgreSQL image' do
    compose = YAML.safe_load_file(Rails.root.join('docker-compose.yml'))
    workflow = YAML.safe_load_file(Rails.root.join('.github/workflows/ruby.yml'))

    assert_equal(
      compose.dig('services', 'postgres-18', 'image'),
      workflow.dig('jobs', 'build_and_test', 'services', 'postgres', 'image')
    )
  end
end

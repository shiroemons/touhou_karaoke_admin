require 'test_helper'
require 'yaml'

class RecurringConfigTest < ActiveSupport::TestCase
  test 'production recurring tasks include admin operation progress pruning' do
    config = YAML.safe_load_file(Rails.root.join('config/recurring.yml'), aliases: true)
    task = config.dig('production', 'prune_admin_operation_progresses')

    assert_equal 'Admin::OperationProgress.prune_older_than!(7.days.ago)', task.fetch('command')
    assert_equal 'every day at 3:20am', task.fetch('schedule')
  end
end

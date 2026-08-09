require 'test_helper'
require 'fugit'
require 'yaml'

class RecurringConfigTest < ActiveSupport::TestCase
  test 'production recurring tasks include admin operation progress pruning' do
    config = YAML.safe_load_file(Rails.root.join('config/recurring.yml'), aliases: true)
    task = config.dig('production', 'prune_admin_operation_progresses')
    schedule = task.fetch('schedule')

    assert_equal 'Admin::OperationProgress.prune_older_than!(7.days.ago)', task.fetch('command')
    assert_equal 'every day at 3:20am Asia/Tokyo', schedule

    cron = Fugit.parse(schedule)

    assert_instance_of Fugit::Cron, cron
    assert_equal 'Asia/Tokyo', cron.zone
    assert_equal Time.utc(2026, 8, 8, 18, 20), cron.next_time(Time.utc(2026, 8, 8, 17)).to_t.utc
  end
end

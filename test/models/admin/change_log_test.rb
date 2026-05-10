require 'test_helper'

module Admin
  class ChangeLogTest < ActiveSupport::TestCase
    test 'records create events with visible field labels' do
      resource = ResourceRegistry.fetch(:circle)
      circle = Circle.create!(name: '変更ログサークル')

      assert_difference -> { ChangeLog.count }, 1 do
        ChangeLog.record_create!(resource:, record: circle, actor_name: '管理者')
      end

      log = ChangeLog.last
      assert_equal 'circle', log.resource_key
      assert_equal 'サークル', log.resource_label
      assert_equal circle.id, log.record_id
      assert_equal '変更ログサークル', log.record_title
      assert_equal 'create', log.event
      assert_equal '管理者', log.actor_name
      assert_equal 'サークル名', log.changed_fields.fetch('name').fetch('label')
      assert_not log.changed_fields.key?('created_at')
      assert_not log.changed_fields.key?('updated_at')
    end

    test 'skips update events when no visible fields changed' do
      resource = ResourceRegistry.fetch(:circle)
      circle = Circle.create!(name: '変更なし')
      circle.update!(updated_at: Time.current)

      assert_no_difference -> { ChangeLog.count } do
        ChangeLog.record_update!(resource:, record: circle, actor_name: '管理者')
      end
    end

    test 'returns latest create or update log for each record' do
      resource = ResourceRegistry.fetch(:circle)
      circle = Circle.create!(name: '最新ログ')
      old_log = ChangeLog.record_create!(resource:, record: circle, actor_name: '管理者')
      circle.update!(name: '最新ログ更新')
      new_log = ChangeLog.record_update!(resource:, record: circle, actor_name: '管理者')

      latest = ChangeLog.latest_for_records('circle', [circle])

      assert_equal new_log, latest.fetch(circle.id)
      assert_operator new_log.created_at, :>=, old_log.created_at
    end

    test 'records destroy events without changed fields' do
      resource = ResourceRegistry.fetch(:circle)
      circle = Circle.create!(name: '削除ログ')

      ChangeLog.record_destroy!(resource:, record: circle, actor_name: '管理者')

      log = ChangeLog.last
      assert_equal 'destroy', log.event
      assert_empty log.changed_fields
    end
  end
end

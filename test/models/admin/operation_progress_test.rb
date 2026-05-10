require 'test_helper'

module Admin
  class OperationProgressTest < ActiveSupport::TestCase
    test 'validates progress ids conservatively' do
      assert OperationProgress.valid_id?(SecureRandom.uuid)
      assert_not OperationProgress.valid_id?('invalid')
      assert_not OperationProgress.valid_id?(nil)
    end

    test 'returns pending payload for missing or invalid ids' do
      invalid = OperationProgress.read('invalid')
      missing = OperationProgress.read(SecureRandom.uuid)

      assert_equal 'pending', invalid[:state]
      assert_equal '待機中', missing[:status]
      assert_equal 0, missing[:percentage]
    end

    test 'persists queued running updated completed and failed states' do
      id = SecureRandom.uuid

      OperationProgress.enqueue!(id, label: '待機しています')
      assert_equal 'queued', OperationProgress.read(id)[:state]

      OperationProgress.start!(id, label: '開始しました')
      assert_equal 'running', OperationProgress.read(id)[:state]

      OperationProgress.update!(id, percentage: 200, current: 3, total: 4, detail: '進行中')
      updated = OperationProgress.read(id)
      assert_equal 100, updated[:percentage]
      assert_equal 3, updated[:current]
      assert_equal 4, updated[:total]
      assert_equal '進行中', updated[:detail]

      OperationProgress.complete!(id, label: '完了しました')
      assert_equal 'completed', OperationProgress.read(id)[:state]

      OperationProgress.fail!(id, message: '失敗しました')
      failed = OperationProgress.read(id)
      assert_equal 'failed', failed[:state]
      assert_equal '失敗しました', failed[:detail]
    end

    test 'ignores invalid ids without creating records' do
      assert_no_difference -> { OperationProgress::Record.count } do
        OperationProgress.start!('invalid', label: '開始')
        OperationProgress.update!('invalid', percentage: 50)
        OperationProgress.complete!('invalid', label: '完了')
        OperationProgress.fail!('invalid', message: '失敗')
      end
    end
  end
end

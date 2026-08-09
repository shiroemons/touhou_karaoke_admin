require 'test_helper'
require 'stringio'

module Admin
  class OperationJobTest < ActiveJob::TestCase
    FakeRunnerResult = Data.define(:message, :download_data, :download_filename, :download_content_type, :metadata)

    test 'logs operation context when running an admin operation' do
      log_output = StringIO.new
      progress_id = SecureRandom.uuid

      with_logger(ActiveSupport::Logger.new(log_output)) do
        stub_operation_runner do
          OperationJob.perform_now(
            resource_key: 'dam_song',
            operation_key: 'fetch_dam_touhou_songs',
            record_id: nil,
            actor_name: 'Admin tester',
            params: {
              operation: 'fetch_dam_touhou_songs',
              operation_progress_id: progress_id,
              selected_ids: %w[1 2 2],
              operation_fields: { 'dry_run' => '1' }
            }
          )
        end
      end

      logs = log_output.string
      assert_includes logs, 'Admin::OperationJob started resource=dam_song operation=fetch_dam_touhou_songs'
      assert_includes logs, "progress_id=#{progress_id}"
      assert_includes logs, 'target_scope=all'
      assert_includes logs, 'actor=Admin tester'
      assert_includes logs, 'selected_ids_count=2'
      assert_includes logs, 'operation_field_keys=dry_run'
      assert_includes logs, 'param_keys=operation'
      assert_includes logs, 'Admin::OperationJob completed resource=dam_song operation=fetch_dam_touhou_songs'
    end

    test 'scopes selection-based async operations to submitted ids' do
      selected = create_song(title: '選択対象')
      unselected = create_song(title: '未選択対象')
      captured_scope = nil

      stub_operation_runner(capture: ->(args) { captured_scope = args.fetch(:scope) }) do
        OperationJob.perform_now(
          resource_key: 'song',
          operation_key: 'export_songs',
          record_id: nil,
          actor_name: 'Admin tester',
          params: {
            operation: 'export_songs',
            operation_progress_id: SecureRandom.uuid,
            selected_ids: [selected.id]
          }
        )
      end

      assert_equal [selected.id], captured_scope.pluck(:id)
      assert_not_includes captured_scope.pluck(:id), unselected.id
    end

    test 'rejects selection-based async operations without submitted ids' do
      assert_raises ArgumentError, '対象を選択してください。' do
        OperationJob.perform_now(
          resource_key: 'song',
          operation_key: 'export_songs',
          record_id: nil,
          actor_name: 'Admin tester',
          params: { operation: 'export_songs', operation_progress_id: SecureRandom.uuid }
        )
      end
    end

    private

    def with_logger(logger)
      original_logger = Rails.logger
      Rails.logger = logger
      yield
    ensure
      Rails.logger = original_logger
    end

    def stub_operation_runner(capture: nil)
      original_new = OperationRunner.method(:new)
      OperationRunner.define_singleton_method(:new) do |**args|
        capture&.call(args)
        runner = Object.new
        runner.define_singleton_method(:run) do
          FakeRunnerResult.new('ok', nil, nil, nil, {})
        end
        runner
      end
      yield
    ensure
      OperationRunner.define_singleton_method(:new, original_new)
    end
  end
end

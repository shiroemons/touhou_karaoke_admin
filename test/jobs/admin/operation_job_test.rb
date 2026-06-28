require 'test_helper'
require 'stringio'

module Admin
  class OperationJobTest < ActiveJob::TestCase
    FakeRunnerResult = Data.define(:message, :download_data, :download_filename, :download_content_type)

    test 'logs operation context when running an admin operation' do
      log_output = StringIO.new
      progress_id = SecureRandom.uuid

      with_logger(ActiveSupport::Logger.new(log_output)) do
        stub_operation_runner do
          OperationJob.perform_now(
            resource_key: 'dam_song',
            operation_key: 'fetch_dam_touhou_songs',
            record_id: nil,
            params: { operation_progress_id: progress_id }
          )
        end
      end

      logs = log_output.string
      assert_includes logs, 'Admin::OperationJob started resource=dam_song operation=fetch_dam_touhou_songs'
      assert_includes logs, "progress_id=#{progress_id}"
      assert_includes logs, 'Admin::OperationJob completed resource=dam_song operation=fetch_dam_touhou_songs'
    end

    private

    def with_logger(logger)
      original_logger = Rails.logger
      Rails.logger = logger
      yield
    ensure
      Rails.logger = original_logger
    end

    def stub_operation_runner
      original_new = OperationRunner.method(:new)
      OperationRunner.define_singleton_method(:new) do |**_args|
        runner = Object.new
        runner.define_singleton_method(:run) do
          FakeRunnerResult.new('ok', nil, nil, nil)
        end
        runner
      end
      yield
    ensure
      OperationRunner.define_singleton_method(:new, original_new)
    end
  end
end

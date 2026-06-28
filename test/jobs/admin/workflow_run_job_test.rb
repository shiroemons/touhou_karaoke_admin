require 'test_helper'
require 'stringio'

module Admin
  class WorkflowRunJobTest < ActiveJob::TestCase
    FakeRunnerResult = Data.define(:message, :download_data, :download_filename, :download_content_type)

    test 'repeatable steps run until no new records are added' do
      run_id = SecureRandom.uuid
      workflow = WorkflowDefinition.fetch('dam')
      WorkflowRunProgress.create!(run_id, workflow:)
      calls = Hash.new(0)

      fake_runner = lambda do |operation_key, progress_id|
        calls[operation_key] += 1
        detail = if operation_key == 'fetch_dam_touhou_songs' && calls[operation_key] == 1
                   'DB変更: DAM楽曲一覧 追加2件'
                 else
                   '変更なし（追加・更新・削除はありません）'
                 end
        OperationProgress.complete!(progress_id, label: "#{operation_key}完了", detail:)
        FakeRunnerResult.new("#{operation_key}完了", nil, nil, nil)
      end

      stub_operation_runner(fake_runner) do
        WorkflowRunJob.perform_now(workflow_key: 'dam', progress_id: run_id)
      end

      payload = WorkflowRunProgress.read(run_id)
      fetch_step = payload.dig(:workflow, :steps).find { |step| step[:operation_key] == 'fetch_dam_touhou_songs' }

      assert_equal 'completed', payload[:state]
      assert_equal 2, calls['fetch_dam_touhou_songs']
      assert_equal 1, calls['fetch_dam_artist']
      assert_equal 1, calls['fetch_dam_songs']
      assert_equal 2, fetch_step[:attempt]
      assert_equal 2, fetch_step[:attempts].size
      assert_includes fetch_step[:attempts].first[:detail], '追加2件'
      assert_includes payload.dig(:workflow, :result_steps).pluck(:label), 'DAM候補一覧を取得'
    end

    test 'repeatable steps stop at max attempts while additions continue' do
      run_id = SecureRandom.uuid
      workflow = WorkflowDefinition.fetch('dam')
      WorkflowRunProgress.create!(run_id, workflow:)
      calls = Hash.new(0)

      fake_runner = lambda do |operation_key, progress_id|
        calls[operation_key] += 1
        OperationProgress.complete!(progress_id, label: "#{operation_key}完了", detail: 'DB変更: DAM楽曲一覧 追加1件')
        FakeRunnerResult.new("#{operation_key}完了", nil, nil, nil)
      end

      stub_operation_runner(fake_runner) do
        WorkflowRunJob.perform_now(workflow_key: 'dam', progress_id: run_id)
      end

      payload = WorkflowRunProgress.read(run_id)
      fetch_step = payload.dig(:workflow, :steps).find { |step| step[:operation_key] == 'fetch_dam_touhou_songs' }

      assert_equal 3, calls['fetch_dam_touhou_songs']
      assert_equal 3, fetch_step[:attempt]
      assert_equal 3, fetch_step[:attempts].size
    end

    test 'logs workflow and step context' do
      run_id = SecureRandom.uuid
      workflow = WorkflowDefinition.fetch('dam')
      WorkflowRunProgress.create!(run_id, workflow:)
      log_output = StringIO.new

      fake_runner = lambda do |operation_key, progress_id|
        OperationProgress.complete!(progress_id, label: "#{operation_key}完了", detail: '変更なし（追加・更新・削除はありません）')
        FakeRunnerResult.new("#{operation_key}完了", nil, nil, nil)
      end

      with_logger(ActiveSupport::Logger.new(log_output)) do
        stub_operation_runner(fake_runner) do
          WorkflowRunJob.perform_now(workflow_key: 'dam', progress_id: run_id, actor_name: 'Workflow tester')
        end
      end

      logs = log_output.string
      assert_includes logs, "Admin::WorkflowRunJob started workflow=dam progress_id=#{run_id}"
      assert_includes logs, 'actor=Workflow tester'
      assert_includes logs, 'Admin::WorkflowRunJob step started'
      assert_includes logs, 'resource=dam_song operation=fetch_dam_touhou_songs attempt=1'
      assert_includes logs, 'selected_ids_count=0 operation_field_keys=- param_keys=-'
      assert_includes logs, 'Admin::WorkflowRunJob step completed'
      assert_includes logs, "Admin::WorkflowRunJob completed workflow=dam progress_id=#{run_id}"
    end

    private

    def with_logger(logger)
      original_logger = Rails.logger
      Rails.logger = logger
      yield
    ensure
      Rails.logger = original_logger
    end

    def stub_operation_runner(fake_runner)
      original_new = OperationRunner.method(:new)
      OperationRunner.define_singleton_method(:new) do |operation:, params:, **_unused|
        runner = Object.new
        runner.define_singleton_method(:run) do
          fake_runner.call(operation.key, params[:operation_progress_id])
        end
        runner
      end
      yield
    ensure
      OperationRunner.define_singleton_method(:new, original_new)
    end
  end
end

# frozen_string_literal: true

module Admin
  class WorkflowRunJob < ApplicationJob
    queue_as :admin_operations

    def perform(workflow_key:, progress_id:, actor_name: nil)
      workflow = WorkflowDefinition.fetch(workflow_key)
      actor = OperationLogContext.actor_name(actor_name)
      Rails.logger.info("Admin::WorkflowRunJob started workflow=#{workflow.key} progress_id=#{progress_id} actor=#{actor}")
      WorkflowRunProgress.start!(progress_id, workflow:)

      workflow.stages.each do |stage|
        WorkflowRunProgress.update_stage!(progress_id, label: "#{stage.label}を実行しています")
        if stage.parallel
          run_stage_in_parallel(progress_id, stage, actor)
        else
          stage.branches.each { |branch| run_branch(progress_id, stage, branch, actor) }
        end
      end

      WorkflowRunProgress.complete!(progress_id, workflow:)
      Rails.logger.info("Admin::WorkflowRunJob completed workflow=#{workflow.key} progress_id=#{progress_id} actor=#{actor}")
    rescue StandardError => e
      WorkflowRunProgress.fail!(progress_id, message: e.message)
      Rails.logger.error(e.full_message)
      raise
    end

    private

    def run_stage_in_parallel(progress_id, stage, actor)
      threads = stage.branches.map do |branch|
        Thread.new do
          Rails.application.executor.wrap do
            ActiveRecord::Base.connection_pool.with_connection do
              run_branch(progress_id, stage, branch, actor)
            end
          end
        end
      end
      threads.each(&:join)
      failed_thread = threads.find { |thread| thread[:error] }
      raise failed_thread[:error] if failed_thread
    end

    def run_branch(progress_id, stage, branch, actor)
      branch.steps.select(&:numbered).each do |step|
        run_step(progress_id, stage, branch, step, actor)
      end
    rescue StandardError => e
      Thread.current[:error] = e
      raise
    end

    def run_step(progress_id, stage, branch, step, actor)
      resource = ResourceRegistry.fetch(step.resource_key)
      operation = resource.operations.find { |item| item.key == step.operation_key } ||
                  raise(ArgumentError, "指定されたアクションは見つかりません: #{step.operation_key}")
      step_key = "#{stage.key}:#{branch.key}:#{step.key}"
      max_attempts = repeatable_step?(step, operation) ? operation.max_attempts : 1
      attempt = 0

      loop do
        attempt += 1
        child_progress_id = SecureRandom.uuid
        operation_params = { operation_progress_id: child_progress_id }
        params_summary = OperationLogContext.params_summary(operation_params)
        Rails.logger.info(
          "Admin::WorkflowRunJob step started workflow_progress_id=#{progress_id} step=#{step_key} " \
          "resource=#{resource.key} operation=#{operation.key} attempt=#{attempt} progress_id=#{child_progress_id} " \
          "actor=#{actor} #{params_summary}"
        )
        WorkflowRunProgress.mark_step!(progress_id, step_key, status: 'running', progress_id: child_progress_id, attempt:)
        OperationProgress.enqueue!(child_progress_id, label: "#{operation.label}を開始待ちです")
        result = OperationRunner.new(
          resource:,
          operation:,
          record: nil,
          params: operation_params,
          scope: resource.model.all
        ).run
        detail = OperationProgress.read(child_progress_id)[:detail]
        WorkflowRunProgress.mark_step!(progress_id, step_key, status: 'completed', progress_id: child_progress_id, attempt:, detail:)
        Rails.logger.info(
          "Admin::WorkflowRunJob step completed workflow_progress_id=#{progress_id} step=#{step_key} " \
          "resource=#{resource.key} operation=#{operation.key} attempt=#{attempt} progress_id=#{child_progress_id} " \
          "actor=#{actor} #{params_summary}"
        )
        break unless repeat_step?(result, detail, attempt, max_attempts)
      end
    rescue StandardError => e
      WorkflowRunProgress.mark_step!(progress_id, step_key, status: 'failed', progress_id: child_progress_id, error: e.message) if defined?(step_key)
      raise
    end

    def repeatable_step?(step, operation)
      step.numbered && operation.repeat_while_created
    end

    def repeat_step?(result, detail, attempt, max_attempts)
      attempt < max_attempts && created_count(result, detail).positive?
    end

    def created_count(result, detail)
      metadata_count = result_metadata_created_count(result)
      return metadata_count if metadata_count

      detail.to_s.scan(/追加(\d+)件/).sum { |match| match.first.to_i }
    end

    def result_metadata_created_count(result)
      return unless result.respond_to?(:metadata)

      result.metadata.dig(:change_summary, :created_count)
    end
  end
end

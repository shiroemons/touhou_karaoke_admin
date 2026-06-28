# frozen_string_literal: true

module Admin
  class WorkflowRunJob < ApplicationJob
    queue_as :admin_operations
    REPEATABLE_OPERATION_KEYS = %w[
      fetch_music_post
      fetch_music_post_song_joysound_url
      fetch_joysound_music_post_artist
      fetch_joysound_music_post_song
      fetch_joysound_touhou_songs
      fetch_joysound_songs
      fetch_joysound_artist
      fetch_dam_touhou_songs
      fetch_dam_artist
      fetch_dam_songs
    ].freeze
    MAX_STEP_ATTEMPTS = 3

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
      max_attempts = repeatable_step?(step) ? MAX_STEP_ATTEMPTS : 1
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
        OperationRunner.new(
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
        break unless repeat_step?(detail, attempt, max_attempts)
      end
    rescue StandardError => e
      WorkflowRunProgress.mark_step!(progress_id, step_key, status: 'failed', progress_id: child_progress_id, error: e.message) if defined?(step_key)
      raise
    end

    def repeatable_step?(step)
      step.numbered && REPEATABLE_OPERATION_KEYS.include?(step.operation_key)
    end

    def repeat_step?(detail, attempt, max_attempts)
      attempt < max_attempts && created_count(detail).positive?
    end

    def created_count(detail)
      detail.to_s.scan(/追加(\d+)件/).sum { |match| match.first.to_i }
    end
  end
end

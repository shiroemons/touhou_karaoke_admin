# frozen_string_literal: true

module Admin
  class WorkflowRunProgress
    ACTIVE_STATES = %w[queued running].freeze

    class << self
      def create!(id, workflow:)
        OperationProgress.enqueue!(id, label: "#{workflow.label}を開始待ちです")
        OperationProgress.update!(id, status: 'ジョブ待機中')
        update_detail!(id) { build_payload(workflow) }
      end

      def read(id)
        progress = OperationProgress.read(id)
        workflow = detail_payload(progress[:detail])
        workflow[:steps]&.each do |step|
          step[:progress] = OperationProgress.read(step[:progress_id]) if step[:progress_id].present?
          step[:detail] ||= step.dig(:progress, :detail) if step[:status] == 'completed'
        end
        workflow[:current_step] = current_step_payload(workflow[:steps])
        workflow[:result_steps] = result_steps_payload(workflow[:steps])
        progress[:percentage] = workflow_percentage(progress, workflow)
        progress.merge(workflow:)
      end

      def active_conflict_for(workflow)
        target_steps = executable_step_signatures(workflow)
        active_records.find do |record|
          payload = detail_payload(record.detail)
          next false if payload[:workflow_key].blank?

          executable_step_signatures_from_payload(payload).intersect?(target_steps)
        end
      end

      def start!(id, workflow:)
        OperationProgress.update!(id, state: 'running', percentage: 0, status: '開始待ち', label: "#{workflow.label}を実行しています")
      end

      def complete!(id, workflow:)
        OperationProgress.update!(id, state: 'completed', percentage: 100, status: '完了', label: "#{workflow.label}が完了しました")
      end

      def fail!(id, message:)
        OperationProgress.update!(id, state: 'failed', status: 'エラー', label: "処理中にエラーが発生しました: #{message}")
      end

      def mark_step!(id, step_key, status:, **attributes)
        progress_id = attributes[:progress_id]
        error = attributes[:error]
        attempt = attributes[:attempt]
        detail = attributes[:detail]

        update_detail!(id) do |payload|
          step = payload[:steps].find { |item| item[:key] == step_key }
          if step
            step[:status] = status
            step[:progress_id] = progress_id if progress_id
            step[:error] = error if error
            step[:attempt] = attempt if attempt
            step[:detail] = detail if detail
            if attempt && detail
              attempts = step[:attempts] ||= []
              attempts.reject! { |item| item[:attempt].to_i == attempt.to_i }
              attempts << { attempt:, detail:, progress_id: }
            end
          end
          payload[:completed_steps] = payload[:steps].count { |item| item[:status] == 'completed' }
          payload[:failed_steps] = payload[:steps].count { |item| item[:status] == 'failed' }
          payload[:result_steps] = payload[:steps].select { |item| item[:detail].present? }.map do |item|
            item.slice(:key, :label, :status, :detail, :attempt, :attempts)
          end
          payload
        end
        update_parent_percentage!(id)
      end

      def update_stage!(id, label:)
        OperationProgress.update!(id, status: '実行中', label:)
      end

      private

      def active_records
        OperationProgress::Record
          .where(state: ACTIVE_STATES)
          .where(updated_at: OperationProgress::CACHE_TTL.ago..)
          .order(updated_at: :desc)
      end

      def build_payload(workflow)
        steps = workflow.stages.flat_map.with_index do |stage, stage_index|
          stage.branches.flat_map do |branch|
            branch.steps.map.with_index do |step, step_index|
              resource = ResourceRegistry.fetch(step.resource_key)
              operation = resource.operations.find { |item| item.key == step.operation_key }
              {
                key: "#{stage.key}:#{branch.key}:#{step.key}",
                stage_key: stage.key,
                stage_label: stage.label,
                branch_key: branch.key,
                branch_label: branch.label,
                stage_index:,
                step_index:,
                resource_key: step.resource_key,
                operation_key: step.operation_key,
                label: operation&.label || step.operation_key,
                note: step.note,
                status: step.numbered ? 'pending' : 'manual',
                progress_id: nil,
                error: nil
              }
            end
          end
        end

        {
          workflow_key: workflow.key,
          workflow_label: workflow.label,
          total_steps: steps.count { |step| step[:status] != 'manual' },
          completed_steps: 0,
          failed_steps: 0,
          steps:
        }
      end

      def executable_step_signatures(workflow)
        workflow.stages.flat_map do |stage|
          stage.branches.flat_map do |branch|
            branch.steps.select(&:numbered).map { |step| "#{step.resource_key}:#{step.operation_key}" }
          end
        end
      end

      def executable_step_signatures_from_payload(payload)
        payload.fetch(:steps, []).filter_map do |step|
          "#{step[:resource_key]}:#{step[:operation_key]}" if step[:status] != 'manual'
        end
      end

      def current_step_payload(steps)
        return nil if steps.blank?

        current = steps.find { |step| step[:status] == 'running' } ||
                  steps.find { |step| step[:status] == 'failed' } ||
                  steps.find { |step| step[:status] == 'pending' }
        return nil unless current

        current.slice(:key, :label, :stage_label, :branch_label, :status, :progress)
      end

      def result_steps_payload(steps)
        Array(steps).select { |step| step[:detail].present? }.map do |step|
          step.slice(:key, :label, :status, :detail, :attempt, :attempts)
        end
      end

      def workflow_percentage(progress, workflow)
        return 100 if progress[:state] == 'completed'

        total = workflow[:total_steps].to_i
        return progress[:percentage].to_i.clamp(0, 100) unless total.positive?

        completed = workflow[:completed_steps].to_i
        running = workflow.fetch(:steps, []).find { |step| step[:status] == 'running' }
        running_ratio = running ? (running.dig(:progress, :percentage).to_i.clamp(0, 100) / 100.0) : 0
        (((completed + running_ratio) / total) * 100).floor.clamp(0, progress[:state] == 'failed' ? 100 : 99)
      end

      def update_parent_percentage!(id)
        payload = detail_payload(OperationProgress.read(id)[:detail])
        total = payload[:total_steps].to_i
        completed = payload[:completed_steps].to_i
        percentage = total.positive? ? ((completed.to_f / total) * 100).floor.clamp(0, 99) : 0
        OperationProgress.update!(id, percentage:, current: completed, total:)
      end

      def update_detail!(id)
        record = OperationProgress::Record.find(id)
        record.with_lock do
          payload = yield(detail_payload(record.detail))
          record.update!(detail: JSON.generate(payload.deep_stringify_keys))
          Rails.cache.write("admin:operation_progress:#{id}", OperationProgress.read(id).merge(detail: record.detail), expires_in: OperationProgress::CACHE_TTL)
        end
      end

      def detail_payload(detail)
        return {} if detail.blank?

        JSON.parse(detail).deep_symbolize_keys
      rescue JSON::ParserError
        {}
      end
    end
  end
end

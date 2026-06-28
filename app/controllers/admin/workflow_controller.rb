module Admin
  class WorkflowController < BaseController
    def index
      @workflow_order = ['JOYSOUND(うたスキ)', 'JOYSOUND', 'DAM']
      @workflow_groups = workflow_groups
      @workflow_operation_resources = @workflow_groups.flat_map { |group| group[:actions].map { |action| action[:resource] } }.uniq
      @workflow_notes = workflow_notes
    end

    def show
      @workflow = WorkflowDefinition.fetch(params[:workflow_key])
      @workflow_groups = workflow_groups([@workflow])
      @workflow_operation_resources = @workflow_groups.flat_map { |group| group[:actions].map { |action| action[:resource] } }.uniq
      @active_workflow_run = active_workflow_run_for(@workflow)
      @workflow_run_id = params[:run_id].presence || active_run_id_for_current_workflow
      @workflow_run = WorkflowRunProgress.read(@workflow_run_id) if @workflow_run_id.present?
    end

    def run
      workflow = WorkflowDefinition.fetch(params[:workflow_key])
      raise ActionController::RoutingError, 'Not Found' if workflow.key == 'common'

      if (active_run = active_workflow_run_for(workflow))
        respond_to do |format|
          format.json { render json: active_run.merge(message: '既に自動実行中です。'), status: :conflict }
          format.html do
            redirect_to(
              admin_workflow_steps_path(active_run[:workflow_key], run_id: active_run[:id]),
              alert: "#{active_run[:workflow_label]}を実行中のため、新しい自動実行は開始しませんでした。"
            )
          end
        end
        return
      end

      progress_id = SecureRandom.uuid

      WorkflowRunProgress.create!(progress_id, workflow:)
      WorkflowRunJob.perform_later(workflow_key: workflow.key, progress_id:, actor_name: current_user.name)

      respond_to do |format|
        format.json { render json: WorkflowRunProgress.read(progress_id), status: :accepted }
        format.html { redirect_to admin_workflow_steps_path(workflow.key, run_id: progress_id), notice: "#{workflow.label}を開始しました。" }
      end
    end

    def progress
      WorkflowDefinition.fetch(params[:workflow_key])

      render json: WorkflowRunProgress.read(params[:run_id])
    end

    private

    def active_workflow_run_for(workflow)
      record = WorkflowRunProgress.active_conflict_for(workflow)
      return unless record

      payload = WorkflowRunProgress.read(record.id)
      {
        id: record.id,
        workflow_key: payload.dig(:workflow, :workflow_key),
        workflow_label: payload.dig(:workflow, :workflow_label),
        state: payload[:state],
        status: payload[:status],
        label: payload[:label],
        percentage: payload[:percentage],
        updated_at: payload[:updated_at]
      }
    end

    def active_run_id_for_current_workflow
      return unless @active_workflow_run&.dig(:workflow_key) == @workflow.key

      @active_workflow_run[:id]
    end

    def workflow_groups(definitions = WorkflowDefinition.listed)
      definitions.map do |definition|
        {
          key: definition.key,
          label: definition.label,
          description: definition.description,
          icon: definition.icon,
          actions: workflow_actions(definition),
          metrics: workflow_metrics(definition)
        }
      end
    end

    def workflow_actions(definition)
      definition.stages.flat_map(&:branches).flat_map(&:steps).filter_map do |step|
        resource = ResourceRegistry.fetch(step.resource_key)
        operation = resource.operations.find { |item| item.key == step.operation_key || item.handler == step.operation_key.to_sym || item.method_name == step.operation_key.to_sym }
        next unless workflow_operation_visible?(operation)

        {
          resource:,
          operation:,
          path: admin_resource_collection_operation_path(resource, operation.key),
          note: step.note,
          cadence: step.cadence,
          kind: step.kind,
          numbered: step.numbered
        }
      end
    end

    def workflow_operation_visible?(operation)
      operation.present? && operation.selection != :required
    end

    def workflow_metrics(definition)
      definition.metrics.map do |metric|
        metric.merge(path: public_send(metric[:route_name], metric[:route_options]))
      end
    end

    def workflow_notes
      [
        '全体で回す時は JOYSOUND(うたスキ) → JOYSOUND → DAM。必要な配信種別だけ単独実行してもよい。',
        'JOYSOUNDアーティスト読み補完は、JOYSOUND候補をカラオケ楽曲へ登録した後でないと対象アーティストが作られない。',
        'DAM候補一覧取得は内部リトライとページ巡回を持つが、最終件数の照合まではしていないため、件数が不自然なら再実行する。',
        'ミュージックポストのフルメンテナンスは手順4〜6と期限切れ整理のまとめ実行。手順1〜3の代替ではない。'
      ]
    end
  end
end

module Admin
  module OperationsHelper
    def admin_operation_summary(operation)
      truncate(strip_tags(operation.description.to_s.squish), length: 92)
    end

    def admin_operation_status_labels(operation)
      labels = []
      labels << '選択必須' if operation.selection == :required
      labels << '入力あり' if operation.inputs.present?
      labels << 'バックグラウンド' if operation.async
      labels.presence || ['すぐ実行']
    end

    def admin_operation_cta(operation)
      return '対象を選択して実行' if operation.selection == :required
      return '入力して実行' if operation.inputs.present?

      '実行内容を確認'
    end

    def admin_workflow_step_status_label(step_payload, running: false, numbered: true)
      return '個別実行のみ' unless numbered
      return '未実行' unless running

      status = step_payload&.dig(:status) || 'pending'
      child_progress = step_payload&.dig(:progress) || {}
      label = case status
              when 'pending' then '順番待ち'
              when 'running' then child_progress[:label].presence || '実行中'
              when 'completed' then child_progress[:detail].presence || '完了'
              when 'failed' then step_payload[:error].presence || child_progress[:detail].presence || '失敗'
              else status
              end

      if status == 'running'
        percentage = child_progress[:percentage].to_i.clamp(0, 100)
        label = "#{label} #{percentage}%"
      end
      label
    end
  end
end

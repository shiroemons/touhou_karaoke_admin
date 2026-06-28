module Admin
  class OperationRunner
    class InputError < StandardError; end

    Result = Data.define(:message, :download_data, :download_filename, :download_content_type)

    def initialize(resource:, operation:, record:, params:, scope:)
      @resource = resource
      @operation = operation
      @record = record
      @params = params
      @scope = scope
      @progress_id = params[:operation_progress_id]
    end

    def run
      started_at = Time.current
      change_summary = OperationChangeSummary.new
      change_baseline = change_summary.snapshot
      OperationProgress.start!(progress_id, label: operation.label)
      result = operation.handler.blank? ? run_method_operation : run_handler_operation

      OperationProgress.complete!(
        progress_id,
        label: result.message.presence || '処理が完了しました',
        detail: change_summary.summarize(baseline: change_baseline, started_at:)
      )
      result
    rescue StandardError => e
      OperationProgress.fail!(progress_id, message: e.message)
      raise
    end

    private

    attr_reader :operation, :record, :params, :scope, :progress_id

    def run_method_operation
      target = record || operation_target
      operation_method = target.method(operation.method_name)
      if operation_method.parameters.any? { |type, name| type == :key && name == :progress }
        target.public_send(operation.method_name, progress: method_progress)
      else
        target.public_send(operation.method_name)
      end
      message("#{operation.label}を実行しました。")
    end

    def run_handler_operation
      target = handler_operation_target
      handler_method = target.method(operation.handler)
      if handler_method.parameters.any? { |type, name| type == :key && name == :progress }
        target.public_send(operation.handler, progress: method_progress)
      else
        target.public_send(operation.handler)
      end
    end

    def handler_operation_target
      handler_registry.resolve(operation.handler) || self
    end

    def handler_registry
      @handler_registry ||= Operations::HandlerRegistry.new(resource: @resource, operation:, params:, scope:)
    end

    def method_progress
      lambda do |**attributes|
        OperationProgress.update!(progress_id, **attributes)
      end
    end

    def operation_target
      @resource.model
    end

    def message(text)
      Result.new(message: text, download_data: nil, download_filename: nil, download_content_type: nil)
    end
  end
end

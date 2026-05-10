# frozen_string_literal: true

module Admin
  class OperationJob < ApplicationJob
    queue_as :admin_operations

    def perform(resource_key:, operation_key:, record_id:, params:)
      resource = ResourceRegistry.fetch(resource_key)
      operation = resource.operations.find { |item| item.key == operation_key } ||
                  raise(ArgumentError, '指定されたアクションは見つかりません。')
      record = resource.model.find(record_id) if record_id.present?

      OperationRunner.new(
        resource:,
        operation:,
        record:,
        params: params.with_indifferent_access,
        scope: resource.model.all
      ).run
    rescue StandardError => e
      OperationProgress.fail!(params[:operation_progress_id] || params['operation_progress_id'], message: e.message) if params.is_a?(Hash)
      Rails.logger.error(e.full_message)
      raise
    end
  end
end

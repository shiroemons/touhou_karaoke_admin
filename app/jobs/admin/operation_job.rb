# frozen_string_literal: true

module Admin
  class OperationJob < ApplicationJob
    queue_as :admin_operations

    def perform(resource_key:, operation_key:, record_id:, params:, actor_name: nil)
      resource = ResourceRegistry.fetch(resource_key)
      operation = resource.operations.find { |item| item.key == operation_key } ||
                  raise(ArgumentError, '指定されたアクションは見つかりません。')
      record = resource.model.find(record_id) if record_id.present?
      progress_id = params[:operation_progress_id] || params['operation_progress_id']
      actor = OperationLogContext.actor_name(actor_name)
      params_summary = OperationLogContext.params_summary(params)
      target_scope = operation_target_scope(operation, params, record:)

      Rails.logger.info(
        "Admin::OperationJob started resource=#{resource.key} operation=#{operation.key} " \
        "record_id=#{record_id.presence || '-'} progress_id=#{progress_id.presence || '-'} " \
        "target_scope=#{target_scope} actor=#{actor} #{params_summary}"
      )

      OperationRunner.new(
        resource:,
        operation:,
        record:,
        params: params.with_indifferent_access,
        scope: operation_scope(resource, operation, params)
      ).run

      Rails.logger.info(
        "Admin::OperationJob completed resource=#{resource.key} operation=#{operation.key} " \
        "record_id=#{record_id.presence || '-'} progress_id=#{progress_id.presence || '-'} " \
        "target_scope=#{target_scope} actor=#{actor} #{params_summary}"
      )
    rescue StandardError => e
      OperationProgress.fail!(params[:operation_progress_id] || params['operation_progress_id'], message: e.message) if params.is_a?(Hash)
      Rails.logger.error(e.full_message)
      raise
    end

    private

    def operation_scope(resource, operation, params)
      selected_ids = selected_ids_from(params)
      raise ArgumentError, '対象を選択してください。' if operation.selection == :required && selected_ids.blank?

      return resource.model.where(resource.model.primary_key => selected_ids) if selected_ids.present? && operation.selection != :none

      resource.model.all
    end

    def operation_target_scope(operation, params, record: nil)
      return 'record' if record.present?
      return 'selected' if selected_ids_from(params).present? && operation.selection != :none
      return 'selection_required' if operation.selection == :required

      'all'
    end

    def selected_ids_from(params)
      Array(params[:selected_ids] || params['selected_ids']).map(&:to_s).compact_blank.uniq
    end
  end
end

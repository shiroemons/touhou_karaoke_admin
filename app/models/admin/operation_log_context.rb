# frozen_string_literal: true

module Admin
  class OperationLogContext
    IGNORED_PARAM_KEYS = %w[operation_progress_id selected_ids operation_fields].freeze

    def self.actor_name(value)
      value.presence || 'system'
    end

    def self.params_summary(params)
      new(params).summary
    end

    def initialize(params)
      @params = normalize_params(params)
    end

    def summary
      [
        "selected_ids_count=#{selected_ids_count}",
        "operation_field_keys=#{joined(operation_field_keys)}",
        "param_keys=#{joined(param_keys)}"
      ].join(' ')
    end

    private

    attr_reader :params

    def normalize_params(params)
      return {} if params.blank?
      return params.to_unsafe_h.with_indifferent_access if params.respond_to?(:to_unsafe_h)

      params.to_h.with_indifferent_access
    rescue NoMethodError
      {}
    end

    def selected_ids_count
      Array(params[:selected_ids]).filter_map(&:presence).uniq.size
    end

    def operation_field_keys
      operation_fields = params[:operation_fields]
      return [] unless operation_fields.respond_to?(:keys)

      operation_fields.keys.map(&:to_s).sort
    end

    def param_keys
      params.keys.map(&:to_s).excluding(*IGNORED_PARAM_KEYS).sort
    end

    def joined(values)
      values.presence&.join(',') || '-'
    end
  end
end

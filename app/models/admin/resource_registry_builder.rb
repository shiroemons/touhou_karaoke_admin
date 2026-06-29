# frozen_string_literal: true

module Admin
  module ResourceRegistryBuilder
    private

    def field(name, label:, **options)
      attributes = {
        type: :text,
        index: true,
        show: true,
        form: true,
        readonly: false,
        sortable: false,
        options: nil,
        link: false,
        helper: nil,
        count_association: nil
      }.merge(options)
      Field.new(name:, label:, **attributes)
    end

    def filter(name, label:, options:, type: :auto, &block)
      Filter.new(name:, label:, type:, options:, apply: block)
    end

    def operation(label, **attributes)
      operation_key = attributes.fetch(:key, attributes.fetch(:handler, attributes.fetch(:method_name, label))).to_s
      Operation.new(
        key: operation_key,
        action_key: attributes.fetch(:action_key, operation_key.camelize),
        label:,
        description: attributes.fetch(:description, operation_description(operation_key, attributes, label)),
        method_name: attributes.fetch(:method_name, nil),
        confirmation: attributes.fetch(:confirmation, nil),
        scope: attributes.fetch(:scope, :collection),
        handler: attributes.fetch(:handler, nil),
        inputs: attributes.fetch(:inputs, []),
        group: attributes.fetch(:group, '操作'),
        estimated_seconds: attributes.fetch(:estimated_seconds, nil),
        timeout_seconds: attributes.fetch(:timeout_seconds, default_timeout_seconds(attributes)),
        selection: attributes.fetch(:selection, :none),
        async: attributes.fetch(:async, false),
        repeat_while_created: attributes.fetch(:repeat_while_created, false),
        retry_strategy: attributes.fetch(:retry_strategy, default_retry_strategy(attributes)),
        max_attempts: attributes.fetch(:max_attempts, 1)
      )
    end

    def resource(**attributes)
      model = attributes.fetch(:model)
      fields = fields_with_timestamp(attributes.fetch(:fields), model)

      Resource.new(
        key: attributes.fetch(:key),
        model:,
        label: attributes.fetch(:label),
        title: attributes.fetch(:title),
        navigation: attributes.fetch(:navigation, true),
        includes: attributes.fetch(:includes, []),
        order: attributes.fetch(:order, nil),
        search: attributes.fetch(:search, {}),
        filters: attributes.fetch(:filters, []),
        fields:,
        associations: attributes.fetch(:associations, []),
        operations: attributes.fetch(:operations, []),
        strong_parameters: attributes.fetch(:strong_parameters, nil) || fields.select { |field| field.form && !field.readonly }.map(&:name)
      )
    end

    def fields_with_timestamp(fields, model)
      return fields unless model.column_names.include?('updated_at')
      return fields if fields.any? { |field| field.name.to_sym == :updated_at }

      fields + [
        field(:updated_at, label: '更新日時', type: :datetime, show: false, form: false, readonly: true, sortable: true)
      ]
    end

    def operation_description(operation_key, attributes, label)
      ResourceRegistry::OPERATION_DESCRIPTIONS.fetch(operation_key, attributes.fetch(:confirmation, "#{label}を実行します。"))
    end

    def default_timeout_seconds(attributes)
      attributes[:async] ? 30.minutes.to_i : nil
    end

    def default_retry_strategy(attributes)
      attributes[:repeat_while_created] ? :repeat_while_created : :none
    end
  end
end

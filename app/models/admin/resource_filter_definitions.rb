# frozen_string_literal: true

module Admin
  module ResourceFilterDefinitions
    private

    def exact_filter(name, label:, options:)
      filter(name, label:, options:) do |scope, value|
        scope.where(name => value)
      end
    end

    def association_exact_filter(name, label:, association:, column:, options:)
      filter(name, label:, options:) do |scope, value|
        reflection = scope.klass.reflect_on_association(association)
        next scope unless reflection

        scope.left_outer_joins(association).where(reflection.klass.table_name => { column => value }).distinct
      end
    end

    def boolean_filter(name, label:, true_label:, false_label:)
      filter(name, label:, type: :radio, options: { true_value: true_label, false_value: false_label }) do |scope, value|
        case value
        when 'true_value'
          scope.where(name => true)
        when 'false_value'
          scope.where(name => false)
        else
          scope
        end
      end
    end

    def presence_filter(name, label:, present_label:, blank_label:)
      filter(name, label:, type: :radio, options: { present: present_label, blank: blank_label }) do |scope, value|
        case value
        when 'present'
          scope.where.not(name => '')
        when 'blank'
          scope.where(name => '')
        else
          scope
        end
      end
    end

    def association_presence_filter(name, label:, association:)
      filter(name, label:, type: :radio, options: { present: "#{label}あり", blank: "#{label}なし" }) do |scope, value|
        case value
        when 'present'
          scope.left_outer_joins(association).where.not(association => { id: nil }).distinct
        when 'blank'
          scope.where.missing(association)
        else
          scope
        end
      end
    end

    def date_status_filter(name, label:)
      # 期限切れ→期限が近い順に並べ、まとめての「期限内すべて」は最後に置く
      options = DeliveryDeadlineWindows::WINDOWS.to_h { |window| [window.key.to_sym, window.label] }.merge(active: DeliveryDeadlineWindows::ACTIVE_LABEL)

      filter(name, label:, type: :radio, options:) do |scope, value|
        today = DeliveryDeadlineWindows.current_date
        window = DeliveryDeadlineWindows.fetch(value)

        if value == 'active'
          scope.where(name => today..)
        elsif window
          scope.where(name => window.range(today))
        else
          scope
        end
      end
    end

    def apply_presence_group_filters(scope, values, columns)
      values.reduce(scope) do |filtered_scope, (key, state)|
        column = columns[key.to_sym]
        next filtered_scope unless column

        case state
        when 'present'
          filtered_scope.where.not(column => '')
        when 'missing'
          filtered_scope.where(column => '')
        else
          filtered_scope
        end
      end
    end
  end
end

module Admin
  module FilterControlsHelper
    def admin_filter_control(filter, active_value)
      case admin_filter_control_type(filter)
      when :presence_groups
        admin_presence_group_filter_control(filter, active_value)
      when :checkboxes
        admin_checkbox_filter_control(filter, active_value)
      when :radio
        admin_radio_filter_control(filter, active_value)
      else
        admin_select_filter_control(filter, active_value)
      end
    end

    def admin_filter_field_class(filter)
      [
        'admin-filter-field',
        "admin-filter-field-#{admin_filter_control_type(filter).to_s.dasherize}",
        ('admin-filter-field-wide' if %i[checkboxes presence_groups].include?(filter.type.to_sym))
      ]
    end

    private

    def admin_filter_control_type(filter)
      return filter.type.to_sym unless filter.type.to_sym == :auto

      filter.options.size <= 3 ? :radio : :select
    end

    def admin_select_filter_control(filter, active_value)
      select_tag "filters[#{filter.name}]",
                 options_for_select(filter.options.map { |value, label| [label, value] }, active_value),
                 include_blank: 'すべて',
                 class: 'admin-select select select-bordered',
                 aria: { label: filter.label },
                 data: { admin_auto_submit: true }
    end

    def admin_radio_filter_control(filter, active_value)
      fieldset_tag nil, class: 'admin-filter-choice-group', aria: { label: filter.label } do
        safe_join([admin_radio_filter_choice(filter, '', 'すべて', active_value.blank?)] +
                  filter.options.map { |value, label| admin_radio_filter_choice(filter, value, label, active_value == value.to_s) })
      end
    end

    def admin_checkbox_filter_control(filter, active_value)
      active_values = Array(active_value).map(&:to_s)

      fieldset_tag nil, class: 'admin-filter-choice-group', aria: { label: filter.label } do
        safe_join(filter.options.map { |value, label| admin_checkbox_filter_choice(filter, value, label, active_values.include?(value.to_s)) })
      end
    end

    def admin_radio_filter_choice(filter, value, label, checked)
      input_id = sanitize_to_id("filters_#{filter.name}_#{value.presence || 'all'}")

      tag.label(class: 'admin-filter-choice', for: input_id) do
        radio_button_tag("filters[#{filter.name}]", value, checked, id: input_id, class: 'admin-filter-choice-input', data: { admin_auto_submit: true }) +
          tag.span(label, class: 'admin-filter-choice-label')
      end
    end

    def admin_checkbox_filter_choice(filter, value, label, checked)
      input_id = sanitize_to_id("filters_#{filter.name}_#{value}")

      tag.label(class: 'admin-filter-choice', for: input_id) do
        check_box_tag("filters[#{filter.name}][]", value, checked, id: input_id, class: 'admin-filter-choice-input', data: { admin_auto_submit: true }) +
          tag.span(label, class: 'admin-filter-choice-label')
      end
    end

    def admin_presence_group_filter_control(filter, active_value)
      active_values = active_value.is_a?(Hash) ? active_value : {}

      tag.div(class: 'admin-presence-filter-groups', role: 'group', aria: { label: filter.label }) do
        safe_join(filter.options.map do |value, label|
          admin_presence_group_filter_row(filter, value, label, active_values[value.to_s])
        end)
      end
    end

    def admin_presence_group_filter_row(filter, value, label, active_value)
      tag.div(class: 'admin-presence-filter-row', role: 'group', aria: { label: label }) do
        tag.span(label, class: 'admin-presence-filter-label') +
          tag.div(class: 'admin-presence-filter-options') do
            choices = [
              { value: '', label: '指定なし', checked: active_value.blank? },
              { value: 'present', label: 'あり', checked: active_value == 'present' },
              { value: 'missing', label: 'なし', checked: active_value == 'missing' }
            ]
            safe_join(choices.map { |choice| admin_presence_group_filter_choice(filter, value, choice, label) })
          end
      end
    end

    def admin_presence_group_filter_choice(filter, group, choice, group_label)
      input_id = sanitize_to_id("filters_#{filter.name}_#{group}_#{choice[:value].presence || 'all'}")

      tag.label(class: 'admin-filter-choice admin-presence-filter-choice', for: input_id) do
        radio_button_tag("filters[#{filter.name}][#{group}]", choice[:value], choice[:checked], id: input_id, class: 'admin-filter-choice-input', aria: { label: "#{group_label}: #{choice[:label]}" }, data: { admin_auto_submit: true }) +
          tag.span(choice[:label], class: 'admin-filter-choice-label')
      end
    end
  end
end

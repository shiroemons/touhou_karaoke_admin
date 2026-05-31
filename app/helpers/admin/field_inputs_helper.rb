module Admin
  module FieldInputsHelper
    def admin_field_input(form, field)
      case field.type
      when :select
        form.select(field.name, Array(field.options).map { |option| [option, option] }, { include_blank: true })
      when :belongs_to_select
        form.select(field.name, field_options(field), { include_blank: true })
      when :has_many_select
        admin_has_many_select_input(form, field)
      when :number
        form.number_field(field.name)
      when :boolean
        form.check_box(field.name)
      when :date
        form.date_field(field.name)
      else
        form.text_field(field.name)
      end
    end

    def admin_has_many_select_input(form, field)
      selected_values = Array(form.object.public_send(field.name)).map(&:to_s)
      content_tag(:div, class: 'admin-searchable-select', data: { admin_searchable_select: true }) do
        safe_join(
          [
            hidden_field_tag("#{form.object_name}[#{field.name}][]", ''),
            admin_has_many_select_values(form, field, selected_values),
            form.search_field(
              :"#{field.name}_search",
              name: nil,
              id: nil,
              placeholder: "#{field.label}を検索",
              autocomplete: 'off',
              class: 'admin-input admin-searchable-select-search',
              data: { admin_searchable_select_search: true },
              aria: { label: "#{field.label}を検索" }
            ),
            content_tag(:div, '', class: 'admin-searchable-select-chips', data: { admin_searchable_select_chips: true }),
            admin_has_many_select_options(field, selected_values),
            content_tag(:p, '', class: 'admin-searchable-select-status', data: { admin_searchable_select_status: true })
          ]
        )
      end
    end

    def admin_has_many_select_values(form, field, selected_values)
      content_tag(:div, hidden: true, data: { admin_searchable_select_values: true, input_name: "#{form.object_name}[#{field.name}][]" }) do
        safe_join(selected_values.map { |value| hidden_field_tag("#{form.object_name}[#{field.name}][]", value, data: { admin_searchable_select_value: true }) })
      end
    end

    def admin_has_many_select_options(field, selected_values)
      content_tag(:div, class: 'admin-searchable-select-options', role: 'listbox', hidden: true, aria: { multiselectable: true }, data: { admin_searchable_select_options: true }) do
        safe_join(
          ordered_has_many_options(field, selected_values).map do |label, value|
            admin_has_many_select_option(label, value, selected_values.include?(value.to_s))
          end
        )
      end
    end

    def admin_has_many_select_option(label, value, checked)
      content_tag(:label, class: 'admin-searchable-select-option', role: 'option', data: { admin_searchable_select_option: true, searchable_text: label }) do
        safe_join(
          [
            tag.input(**admin_has_many_select_checkbox_attributes(value, checked)),
            content_tag(:span, label)
          ]
        )
      end
    end

    def admin_has_many_select_checkbox_attributes(value, checked)
      attributes = { type: 'checkbox', value:, data: { admin_searchable_select_checkbox: true } }
      attributes[:checked] = true if checked
      attributes
    end

    def field_options(field) = field.options.respond_to?(:call) ? field.options.call : Array(field.options)

    def ordered_has_many_options(field, selected_values)
      selected_positions = selected_values.each_with_index.to_h
      indexed_options = field_options(field).each_with_index.to_a

      indexed_options.sort_by do |(_label, value), index|
        position = selected_positions[value.to_s]
        position ? [0, position] : [1, index]
      end.map(&:first)
    end
  end
end

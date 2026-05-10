module Admin
  module ResourcesHelper
    include TimestampsHelper

    def admin_field_value(record, field)
      return admin_service_status(record, field.options) if field.type == :service_status
      return admin_cached_association_count(record, field.count_association) if field.count_association

      value = if field.helper
                field.helper.call(record)
              else
                record.public_send(field.name)
              end

      case field.type
      when :url
        admin_url_value(value)
      when :boolean, :boolean_mark
        value.present? ? '✅' : ''
      when :belongs_to
        admin_belongs_to_value(value)
      when :badge
        value.present? ? admin_badge_value(value) : '-'
      when :date
        value&.to_fs(:db)
      when :datetime
        admin_datetime_value(record, value, field)
      else
        return admin_badge_value(value) if field.name.to_sym == :karaoke_type && value.present?

        value.presence || '-'
      end
    end

    def admin_url_value(value)
      return '-' if value.blank?

      link_to(value, value, target: '_blank', rel: 'noopener', class: 'admin-url')
    end

    def admin_badge_value(value)
      content_tag(:span, value, class: ['admin-badge', "admin-badge-#{value.to_s.parameterize}"])
    end

    def admin_belongs_to_value(value)
      return '-' if value.blank?

      resource = Admin::ResourceRegistry.all.values.find { |item| item.model == value.class }
      label = admin_record_title(resource, value)
      resource ? link_to(label, admin_resource_path(resource, value)) : label
    end

    def admin_record_title(resource, record)
      return record.to_s unless resource

      title = resource.title.respond_to?(:call) ? resource.title.call(record) : record.public_send(resource.title)
      title.presence || record.to_s
    end

    def admin_record_identifier(record)
      Array(record.to_key).join('/')
    end

    def admin_association_records(record, association)
      Array(record.public_send(association))
    end

    def admin_association_count(record, association)
      loaded_association = record.association(association) if record.class.reflect_on_association(association)
      return Array(loaded_association.target).compact.size if loaded_association&.loaded?

      value = record.public_send(association)
      value.respond_to?(:count) ? value.count : Array(value).compact.size
    end

    def admin_related_resource(record)
      Admin::ResourceRegistry.all.values.find { |item| item.model == record.class }
    end

    def admin_association_label(association)
      I18n.t("admin.associations.#{association}", default: association.to_s.humanize)
    end

    def admin_field_value_class(record, field)
      [
        'admin-detail-value',
        ('admin-detail-value-url' if field.type == :url),
        ('admin-detail-value-empty' if admin_field_raw_value(record, field).blank?)
      ]
    end

    def admin_field_raw_value(record, field)
      return admin_cached_association_count(record, field.count_association) if field.count_association

      field.helper ? field.helper.call(record) : record.public_send(field.name)
    end

    def admin_field_input(form, field)
      case field.type
      when :select
        form.select(field.name, Array(field.options).map { |option| [option, option] }, { include_blank: true })
      when :belongs_to_select
        form.select(field.name, field_options(field), { include_blank: true })
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

    def field_options(field)
      field.options.respond_to?(:call) ? field.options.call : Array(field.options)
    end

    def admin_page_params(page)
      request.query_parameters.merge(page:)
    end

    def admin_index_params(overrides = {})
      request.query_parameters.except(:partial).merge(overrides).compact
    end
  end
end

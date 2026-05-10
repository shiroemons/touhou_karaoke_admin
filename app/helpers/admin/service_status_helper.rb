module Admin
  module ServiceStatusHelper
    def admin_service_status(record, services)
      content_tag(:div, class: 'admin-service-status') do
        safe_join(services.map { |column, label| admin_service_badge(record, column, label) })
      end
    end

    def admin_service_badge(record, column, label)
      active = record.public_send(column).present?
      content_tag(:span, label, class: ['admin-service-badge', ('admin-service-badge-active' if active)])
    end
  end
end

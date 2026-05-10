module Admin
  module ResourcePathHelper
    def admin_resources_path(resource, options = {})
      public_send("admin_#{resource.route_name}_path", options)
    end

    def admin_resource_path(resource, record, options = {})
      public_send("admin_#{resource.key}_path", record, options)
    end

    def new_admin_resource_path(resource)
      public_send("new_admin_#{resource.key}_path")
    end

    def edit_admin_resource_path(resource, record)
      public_send("edit_admin_#{resource.key}_path", record)
    end

    def admin_resource_operation_path(resource, record, operation_identifier)
      public_send("operation_admin_#{resource.key}_path", record, operation: operation_identifier)
    end

    def admin_resource_collection_operation_path(resource, operation_identifier)
      public_send("operation_admin_#{resource.route_name}_path", operation: operation_identifier)
    end

    def admin_operation_path(resource, record, operation_identifier)
      if record.present?
        admin_resource_operation_path(resource, record, operation_identifier)
      else
        admin_resource_collection_operation_path(resource, operation_identifier)
      end
    end
  end
end

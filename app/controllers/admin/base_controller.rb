module Admin
  class BaseController < ApplicationController
    include Pundit::Authorization
    include ResourcePathHelper

    AdminUser = Struct.new(:name, keyword_init: true)

    layout 'admin'

    helper_method :admin_navigation_groups, :admin_resources, :current_user

    rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
    rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

    private

    def admin_resources
      ResourceRegistry.navigable
    end

    def admin_navigation_groups
      ResourceRegistry.navigation_groups
    end

    def current_user
      AdminUser.new(name: 'Anonymous user')
    end

    def user_not_authorized
      redirect_to admin_root_path, alert: I18n.t('admin.not_authorized')
    end

    def record_not_found
      redirect_to admin_root_path, alert: I18n.t('admin.not_found')
    end
  end
end

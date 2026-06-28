require 'digest'

module Admin
  class BaseController < ApplicationController
    include Pundit::Authorization
    include ResourcePathHelper

    AdminUser = Struct.new(:name, keyword_init: true)
    BASIC_AUTH_USERNAME_ENV = 'TOUHOU_KARAOKE_ADMIN_BASIC_AUTH_USERNAME'.freeze
    BASIC_AUTH_PASSWORD_ENV = 'TOUHOU_KARAOKE_ADMIN_BASIC_AUTH_PASSWORD'.freeze

    layout 'admin'

    helper_method :admin_navigation_groups, :admin_resources, :current_user

    before_action :authenticate_admin

    rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
    rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

    private

    def authenticate_admin
      return unless admin_basic_auth_enabled?

      authenticate_or_request_with_http_basic('Touhou Karaoke Admin') do |username, password|
        secure_compare(username, admin_basic_auth_username) &
          secure_compare(password, admin_basic_auth_password)
      end
    end

    def admin_basic_auth_enabled?
      admin_basic_auth_username.present? && admin_basic_auth_password.present?
    end

    def admin_basic_auth_username
      ENV.fetch(BASIC_AUTH_USERNAME_ENV, nil)
    end

    def admin_basic_auth_password
      ENV.fetch(BASIC_AUTH_PASSWORD_ENV, nil)
    end

    def secure_compare(value, expected)
      ActiveSupport::SecurityUtils.secure_compare(
        Digest::SHA256.hexdigest(value.to_s),
        Digest::SHA256.hexdigest(expected.to_s)
      )
    end

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

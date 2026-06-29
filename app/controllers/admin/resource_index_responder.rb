# frozen_string_literal: true

module Admin
  class ResourceIndexResponder
    def initialize(controller:, rows_request:, content_request:, next_url:)
      @controller = controller
      @rows_request = rows_request
      @content_request = content_request
      @next_url = next_url
    end

    def call
      return false unless rows_request || content_request

      controller.render(json: response_payload)
      true
    end

    private

    attr_reader :controller, :rows_request, :content_request, :next_url

    def response_payload
      if rows_request
        {
          html: controller.render_to_string(partial: 'admin/resources/rows', formats: [:html], layout: false),
          next_url:
        }
      else
        {
          html: controller.render_to_string(template: 'admin/resources/index', formats: [:html], layout: false)
        }
      end
    end
  end
end

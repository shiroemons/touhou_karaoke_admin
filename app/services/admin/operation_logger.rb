# frozen_string_literal: true

module Admin
  class OperationLogger
    LEVELS = %i[debug info warn error].freeze

    def self.log(event:, action:, resource:, level: :info, **attributes)
      level = level.to_sym
      raise ArgumentError, "Unsupported log level: #{level}" unless LEVELS.include?(level)

      Rails.logger.public_send(level) { message(event:, action:, resource:, attributes:) }
    end

    def self.message(event:, action:, resource:, attributes: {})
      parts = {
        event:,
        action:,
        resource:
      }.merge(attributes.compact).map { |key, value| "#{key}=#{format_value(value)}" }

      parts.join(" ")
    end

    def self.format_value(value)
      value.to_s.squish.presence || "-"
    end
    private_class_method :format_value
  end
end

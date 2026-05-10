module Admin
  class ChangeLog < ApplicationRecord
    self.table_name = 'admin_change_logs'

    IGNORED_FIELDS = %w[created_at updated_at].freeze

    validates :resource_key, :resource_label, :record_type, :record_id, :record_title, :event, :actor_name, presence: true

    scope :recent_first, -> { order(created_at: :desc) }

    class << self
      def latest_for_records(resource_key, records)
        record_ids = records.map { |record| record_identifier(record) }
        return {} if record_ids.blank?

        where(resource_key:, record_id: record_ids)
          .where(event: %w[create update])
          .recent_first
          .group_by(&:record_id)
          .transform_values(&:first)
      end

      def recent_for_record(resource_key, record)
        where(resource_key:, record_id: record_identifier(record)).recent_first
      end

      def record_create!(resource:, record:, actor_name:)
        record_event!(resource:, record:, actor_name:, event: 'create', changes: record.previous_changes)
      end

      def record_update!(resource:, record:, actor_name:)
        changes = visible_changes(resource, record.previous_changes)
        return if changes.blank?

        record_event!(resource:, record:, actor_name:, event: 'update', changes: record.previous_changes)
      end

      def record_destroy!(resource:, record:, actor_name:)
        record_event!(resource:, record:, actor_name:, event: 'destroy', changes: {})
      end

      def record_identifier(record)
        Array(record.to_key).join('/')
      end

      private

      def record_event!(resource:, record:, actor_name:, event:, changes:)
        create!(
          resource_key: resource.key.to_s,
          resource_label: resource.label,
          record_type: record.class.name,
          record_id: record_identifier(record),
          record_title: record_title(resource, record),
          event:,
          changed_fields: visible_changes(resource, changes),
          actor_name:
        )
      end

      def visible_changes(resource, changes)
        field_labels = resource.fields.index_by { |field| field.name.to_s }
        changes.except(*IGNORED_FIELDS).each_with_object({}) do |(column, values), result|
          before, after = values
          result[column] = {
            label: field_labels[column]&.label || column,
            before: change_value(before),
            after: change_value(after)
          }
        end
      end

      def change_value(value)
        case value
        when Time, ActiveSupport::TimeWithZone
          I18n.l(value.in_time_zone('Asia/Tokyo'), format: :admin_datetime)
        when Date
          value.to_fs(:db)
        when true, false
          value.to_s
        else
          value.presence&.to_s
        end
      end

      def record_title(resource, record)
        title = resource.title.respond_to?(:call) ? resource.title.call(record) : record.public_send(resource.title)
        title.presence || record.to_s
      end
    end
  end
end

module Admin
  module TimestampsHelper
    def admin_record_row_class(record)
      status = admin_record_change_status(record)

      if status&.fetch(:kind) == :create
        ['admin-row-created']
      elsif status&.fetch(:kind) == :update
        ['admin-row-updated']
      else
        []
      end
    end

    def admin_datetime_value(record, value, field)
      return '-' if value.blank?

      formatted_value = l(value.in_time_zone('Asia/Tokyo'), format: :admin_datetime)
      return formatted_value unless field.name.to_sym == :updated_at

      badge = admin_updated_at_badge(record)
      return formatted_value unless badge

      tag.span(safe_join([tag.span(formatted_value), badge], ' '), class: 'admin-updated-at')
    end

    def admin_updated_at_badge(record)
      status = admin_record_change_status(record)
      return unless status

      tag.span(
        status.fetch(:label),
        class: ['admin-update-badge', "admin-update-badge-#{status.fetch(:kind)}"],
        title: status.fetch(:title)
      )
    end

    def admin_change_log_event_label(change_log)
      { 'create' => '追加', 'update' => '更新', 'destroy' => '削除' }.fetch(change_log.event, change_log.event)
    end

    def admin_change_log_fields_summary(change_log)
      labels = change_log.changed_fields.values.filter_map { |change| change['label'].presence }
      labels.presence&.join('、') || '変更内容なし'
    end

    def admin_change_log_event_class(change_log)
      {
        'create' => 'admin-change-event-create',
        'update' => 'admin-change-event-update',
        'destroy' => 'admin-change-event-destroy'
      }.fetch(change_log.event, nil)
    end

    def admin_change_log_value(value)
      value.presence || '未設定'
    end

    private

    def admin_record_change_status(record)
      change_log = admin_recent_change_log(record)

      return change_log_status(change_log) if change_log && updated_within?(change_log.created_at, 7.days)

      return { kind: :create, label: '追加', title: '直近7日以内に追加' } if recently_created?(record)

      { kind: :update, label: '更新', title: '直近7日以内に更新' } if recently_updated?(record)
    end

    def admin_recent_change_log(record)
      admin_recent_change_logs.fetch(Admin::ChangeLog.record_identifier(record), nil)
    end

    def change_log_status(change_log)
      case change_log.event
      when 'create'
        { kind: :create, label: '追加', title: "追加: #{admin_change_log_fields_summary(change_log)}" }
      when 'update'
        changed_fields = admin_change_log_fields_summary(change_log)
        label = changed_fields == '変更内容なし' ? '更新' : "更新: #{changed_fields}"
        { kind: :update, label:, title: "更新: #{changed_fields}" }
      end
    end

    def recently_created?(record)
      return false unless record.respond_to?(:created_at) && record.respond_to?(:updated_at)
      return false unless updated_within?(record.created_at, 7.days)

      (record.updated_at - record.created_at).abs < 90.seconds
    end

    def recently_updated?(record)
      record.respond_to?(:updated_at) && updated_within?(record.updated_at, 7.days)
    end

    def updated_within?(value, duration)
      value.present? && value >= duration.ago
    end
  end
end

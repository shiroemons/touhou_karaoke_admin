# frozen_string_literal: true

module Admin
  class OperationProgress
    CACHE_TTL = 2.hours
    ID_FORMAT = /\A[0-9a-f-]{36}\z/

    class << self
      def valid_id?(id)
        id.to_s.match?(ID_FORMAT)
      end

      def start!(id, label:)
        return unless valid_id?(id)

        write(id, payload(state: 'running', percentage: 0, status: '開始待ち', label:, detail: nil))
      end

      def update!(id, **attributes)
        return unless valid_id?(id)

        write(id, read(id).merge(normalize(attributes)).merge(updated_at: Time.current.iso8601))
      end

      def complete!(id, label:)
        return unless valid_id?(id)

        update!(id, state: 'completed', percentage: 100, status: '完了', label:, detail: nil)
      end

      def fail!(id, message:)
        return unless valid_id?(id)

        update!(id, state: 'failed', status: 'エラー', label: '処理中にエラーが発生しました', detail: message)
      end

      def read(id)
        return payload(state: 'pending', percentage: 0, status: '待機中', label: '処理を開始しています...', detail: nil) unless valid_id?(id)

        Rails.cache.read(cache_key(id)) || memory_store[id] || payload(state: 'pending', percentage: 0, status: '待機中', label: '処理を開始しています...', detail: nil)
      end

      private

      def write(id, data)
        memory_store[id] = data
        Rails.cache.write(cache_key(id), data, expires_in: CACHE_TTL)
      end

      def memory_store
        @memory_store ||= {}
      end

      def cache_key(id)
        "admin:operation_progress:#{id}"
      end

      def payload(state:, percentage:, status:, label:, detail:)
        {
          state:,
          percentage: percentage.to_i.clamp(0, 100),
          status:,
          label:,
          detail:,
          current: nil,
          total: nil,
          updated_at: Time.current.iso8601
        }
      end

      def normalize(attributes)
        attributes.compact.tap do |normalized|
          normalized[:percentage] = normalized[:percentage].to_i.clamp(0, 100) if normalized.key?(:percentage)
        end
      end
    end
  end
end

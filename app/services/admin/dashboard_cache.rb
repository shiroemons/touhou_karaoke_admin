module Admin
  class DashboardCache
    KEY = 'admin:dashboard:v3'.freeze
    TTL = 5.minutes

    class << self
      def fetch(&)
        Rails.cache.fetch(KEY, expires_in: TTL, &)
      end

      def write(value)
        Rails.cache.write(KEY, value, expires_in: TTL)
      end

      def invalidate!
        Rails.cache.delete(KEY)
      rescue StandardError => e
        Rails.logger.warn { "Admin::DashboardCache invalidation failed: #{e.class}: #{e.message}" }
        false
      end
    end
  end
end

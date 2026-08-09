require 'test_helper'

module Admin
  class DashboardCacheTest < ActiveSupport::TestCase
    test 'invalidates cached dashboard counts' do
      with_cache_store(ActiveSupport::Cache::MemoryStore.new) do
        Rails.cache.write(DashboardCache::KEY, { total_songs: 1 })

        assert DashboardCache.invalidate!
        assert_not Rails.cache.exist?(DashboardCache::KEY)
      end
    end

    test 'does not make a data operation fail when cache invalidation fails' do
      failing_cache = Object.new
      failing_cache.define_singleton_method(:delete) { |_key| raise IOError, 'cache unavailable' }
      original_cache = Rails.cache
      Rails.cache = failing_cache

      assert_equal false, DashboardCache.invalidate!
    ensure
      Rails.cache = original_cache
    end

    private

    def with_cache_store(store)
      original_cache = Rails.cache
      Rails.cache = store
      yield
    ensure
      store.clear
      Rails.cache = original_cache
    end
  end
end

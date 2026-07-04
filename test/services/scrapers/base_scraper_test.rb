# frozen_string_literal: true

require 'test_helper'

module Scrapers
  class BaseScraperTest < ActiveSupport::TestCase
    class FakeBrowserManager
      attr_reader :close_calls, :restart_calls, :reset_session_calls

      def initialize(persistent: false)
        @close_calls = 0
        @restart_calls = 0
        @reset_session_calls = 0
        @persistent = persistent
      end

      def close
        @close_calls += 1
      end

      def restart
        @restart_calls += 1
      end

      def reset_session
        @reset_session_calls += 1
      end

      def started?
        true
      end

      def persistent?
        @persistent
      end
    end

    # BaseScraperはabstractなため、検証用の最小サブクラスを定義する
    class TestScraper < BaseScraper
      def karaoke_type
        "TEST"
      end

      def call_reset_browser_manager(**)
        reset_browser_manager(**)
      end

      def call_track_browser_use
        track_browser_use
      end

      def current_browser_manager
        browser_manager
      end
    end

    test 'shutdown closes the browser manager' do
      fake_manager = FakeBrowserManager.new
      scraper = TestScraper.new(browser_manager: fake_manager)

      scraper.shutdown

      assert_equal 1, fake_manager.close_calls
    end

    test 'shutdown does nothing when the browser manager is nil' do
      scraper = TestScraper.new(browser_manager: nil)

      scraper.shutdown

      assert_nil scraper.current_browser_manager
    end

    test 'reset_browser_manager preserves the persistent flag while applying new options' do
      fake_manager = FakeBrowserManager.new(persistent: true)
      scraper = TestScraper.new(browser_manager: fake_manager)
      replacement_manager = FakeBrowserManager.new(persistent: true)
      captured_args = nil

      with_stubbed_browser_manager_new(replacement_manager, captured: ->(args) { captured_args = args }) do
        scraper.call_reset_browser_manager(timeout: 20, process_timeout: 15)
      end

      assert_equal [{ timeout: 20, process_timeout: 15 }, { persistent: true }], captured_args
      assert_same replacement_manager, scraper.current_browser_manager
    end

    test 'reset_browser_manager keeps a non-persistent manager non-persistent' do
      fake_manager = FakeBrowserManager.new(persistent: false)
      scraper = TestScraper.new(browser_manager: fake_manager)
      replacement_manager = FakeBrowserManager.new(persistent: false)
      captured_args = nil

      with_stubbed_browser_manager_new(replacement_manager, captured: ->(args) { captured_args = args }) do
        scraper.call_reset_browser_manager
      end

      assert_equal [{ timeout: 10, process_timeout: 10 }, { persistent: false }], captured_args
    end

    test 'track_browser_use is a no-op when the browser manager is not persistent' do
      fake_manager = FakeBrowserManager.new(persistent: false)
      scraper = TestScraper.new(browser_manager: fake_manager)

      3.times { scraper.call_track_browser_use }

      assert_equal 0, fake_manager.reset_session_calls
      assert_equal 0, fake_manager.restart_calls
    end

    test 'track_browser_use is a no-op when the browser manager is nil' do
      scraper = TestScraper.new(browser_manager: nil)

      scraper.call_track_browser_use

      assert_nil scraper.current_browser_manager
    end

    test 'track_browser_use resets the session on every call without restarting under the limit' do
      original_max_uses = BaseScraper::SCRAPING_BROWSER_MAX_USES
      BaseScraper.send(:remove_const, :SCRAPING_BROWSER_MAX_USES)
      BaseScraper.const_set(:SCRAPING_BROWSER_MAX_USES, 3)

      fake_manager = FakeBrowserManager.new(persistent: true)
      scraper = TestScraper.new(browser_manager: fake_manager)

      2.times { scraper.call_track_browser_use }

      assert_equal 2, fake_manager.reset_session_calls
      assert_equal 0, fake_manager.restart_calls
    ensure
      BaseScraper.send(:remove_const, :SCRAPING_BROWSER_MAX_USES)
      BaseScraper.const_set(:SCRAPING_BROWSER_MAX_USES, original_max_uses)
    end

    test 'track_browser_use restarts the browser and resets the counter once the limit is reached' do
      original_max_uses = BaseScraper::SCRAPING_BROWSER_MAX_USES
      BaseScraper.send(:remove_const, :SCRAPING_BROWSER_MAX_USES)
      BaseScraper.const_set(:SCRAPING_BROWSER_MAX_USES, 3)

      fake_manager = FakeBrowserManager.new(persistent: true)
      scraper = TestScraper.new(browser_manager: fake_manager)

      3.times { scraper.call_track_browser_use }

      assert_equal 3, fake_manager.reset_session_calls
      assert_equal 1, fake_manager.restart_calls

      # カウンタがリセットされているため、次のtrack_browser_useではrestartが呼ばれない
      scraper.call_track_browser_use
      assert_equal 1, fake_manager.restart_calls
    ensure
      BaseScraper.send(:remove_const, :SCRAPING_BROWSER_MAX_USES)
      BaseScraper.const_set(:SCRAPING_BROWSER_MAX_USES, original_max_uses)
    end

    private

    def with_stubbed_browser_manager_new(replacement_manager, captured:)
      original_new = BrowserManager.method(:new)
      BrowserManager.define_singleton_method(:new) do |*args, **kwargs|
        captured.call([*args, kwargs])
        replacement_manager
      end
      yield
    ensure
      BrowserManager.define_singleton_method(:new) do |*args, **kwargs, &block|
        original_new.call(*args, **kwargs, &block)
      end
    end
  end
end

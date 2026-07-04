require 'test_helper'

class BrowserManagerTest < ActiveSupport::TestCase
  class FakeNetwork
    attr_reader :clear_calls, :wait_for_idle_calls

    def initialize
      @clear_calls = []
      @wait_for_idle_calls = []
    end

    def clear(type)
      @clear_calls << type
    end

    def wait_for_idle(duration:, timeout: nil)
      @wait_for_idle_calls << { duration:, timeout: }
    end
  end

  class FakeBrowser
    attr_reader :quit_calls, :reset_calls, :goto_calls, :network

    def initialize
      @quit_calls = 0
      @reset_calls = 0
      @goto_calls = []
      @network = FakeNetwork.new
    end

    def quit
      @quit_calls += 1
    end

    def reset
      @reset_calls += 1
    end

    def goto(url)
      @goto_calls << url
    end
  end

  test 'with_browser starts and quits a new browser on every call by default' do
    created = []

    with_stubbed_browser_new(created) do
      manager = BrowserManager.new

      manager.with_browser { |browser| browser.goto('https://example.com/1') }
      manager.with_browser { |browser| browser.goto('https://example.com/2') }

      assert_equal 2, created.size
      assert(created.all? { |browser| browser.quit_calls == 1 })
      assert_not manager.started?
    end
  end

  test 'with_browser reuses the same browser and never quits in persistent mode' do
    created = []

    with_stubbed_browser_new(created) do
      manager = BrowserManager.new(persistent: true)

      manager.with_browser { |browser| browser.goto('https://example.com/1') }
      manager.with_browser { |browser| browser.goto('https://example.com/2') }

      assert_equal 1, created.size
      assert_equal 0, created.first.quit_calls
      assert manager.started?
      assert manager.persistent?
    end
  end

  test 'close quits a persistent browser exactly once' do
    created = []

    with_stubbed_browser_new(created) do
      manager = BrowserManager.new(persistent: true)
      manager.with_browser { |browser| browser.goto('https://example.com') }

      manager.close

      assert_equal 1, created.first.quit_calls
      assert_not manager.started?
    end
  end

  test 'restart quits the current browser then starts a fresh one' do
    created = []

    with_stubbed_browser_new(created) do
      manager = BrowserManager.new(persistent: true)
      manager.with_browser { |browser| browser.goto('https://example.com') }
      first_browser = created.first

      manager.restart

      assert_equal 1, first_browser.quit_calls
      assert_equal 2, created.size
      assert manager.started?
    end
  end

  test 'reset_session clears cookies/session state and network traffic when started' do
    created = []

    with_stubbed_browser_new(created) do
      manager = BrowserManager.new(persistent: true)
      manager.with_browser { |browser| browser.goto('https://example.com') }

      manager.reset_session

      assert_equal 1, created.first.reset_calls
      assert_equal [:traffic], created.first.network.clear_calls
    end
  end

  test 'reset_session does nothing when the browser is not started' do
    manager = BrowserManager.new

    manager.reset_session

    assert_not manager.started?
  end

  test 'started? and persistent? reflect manager state' do
    manager = BrowserManager.new
    assert_not manager.started?
    assert_not manager.persistent?

    persistent_manager = BrowserManager.new(persistent: true)
    assert persistent_manager.persistent?
  end

  test 'exceptions inside with_browser propagate and keep the persistent browser alive' do
    created = []

    with_stubbed_browser_new(created) do
      manager = BrowserManager.new(persistent: true)

      error = assert_raises(RuntimeError) do
        manager.with_browser { |_browser| raise 'boom' }
      end

      assert_equal 'boom', error.message
      assert manager.started?
      assert_equal 0, created.first.quit_calls
    end
  end

  test 'exceptions inside with_browser propagate and still quit a non-persistent browser' do
    created = []

    with_stubbed_browser_new(created) do
      manager = BrowserManager.new

      assert_raises(RuntimeError) do
        manager.with_browser { |_browser| raise 'boom' }
      end

      assert_not manager.started?
      assert_equal 1, created.first.quit_calls
    end
  end

  test 'visit waits for idle using the configured timeout' do
    created = []

    with_stubbed_browser_new(created) do
      manager = BrowserManager.new(persistent: true)
      manager.with_browser { manager.visit('https://example.com', wait_duration: 2.0) }

      browser = created.first
      assert_equal ['https://example.com'], browser.goto_calls
      assert_equal [{ duration: 2.0, timeout: 10 }], browser.network.wait_for_idle_calls
    end
  end

  test 'visit routes the actual request through ScrapingRateLimiter.throttle' do
    created = []
    throttle_calls = []

    with_stubbed_browser_new(created) do
      with_stubbed_rate_limiter_throttle(throttle_calls, yields: true) do
        manager = BrowserManager.new(persistent: true)
        manager.with_browser { manager.visit('https://example.com', wait_duration: 2.0) }

        browser = created.first
        assert_equal ['https://example.com'], throttle_calls
        assert_equal ['https://example.com'], browser.goto_calls
        assert_equal [{ duration: 2.0, timeout: 10 }], browser.network.wait_for_idle_calls
      end
    end
  end

  test 'visit does not goto/wait_for_idle unless ScrapingRateLimiter.throttle yields' do
    created = []
    throttle_calls = []

    with_stubbed_browser_new(created) do
      with_stubbed_rate_limiter_throttle(throttle_calls, yields: false) do
        manager = BrowserManager.new(persistent: true)
        manager.with_browser { manager.visit('https://example.com') }

        browser = created.first
        assert_equal ['https://example.com'], throttle_calls
        assert_empty browser.goto_calls
        assert_empty browser.network.wait_for_idle_calls
      end
    end
  end

  private

  def with_stubbed_browser_new(created_browsers)
    original_new = Ferrum::Browser.method(:new)
    Ferrum::Browser.define_singleton_method(:new) do |*_args, **_kwargs|
      FakeBrowser.new.tap { |browser| created_browsers << browser }
    end
    yield
  ensure
    Ferrum::Browser.define_singleton_method(:new) do |*args, **kwargs, &block|
      original_new.call(*args, **kwargs, &block)
    end
  end

  # ScrapingRateLimiter.throttle をスタブし、visit が実際にそのブロック経由で
  # goto/wait_for_idle を呼び出していることを検証できるようにする。
  # yields: false の場合はブロックを呼ばず、goto等がthrottleの外側で呼ばれていないことを確認できる。
  def with_stubbed_rate_limiter_throttle(recorded_urls, yields:)
    original_throttle = ScrapingRateLimiter.method(:throttle)
    ScrapingRateLimiter.define_singleton_method(:throttle) do |url, &block|
      recorded_urls << url
      block.call if yields
    end
    yield
  ensure
    ScrapingRateLimiter.define_singleton_method(:throttle) do |*args, **kwargs, &block|
      original_throttle.call(*args, **kwargs, &block)
    end
  end
end

require 'test_helper'

class ScrapingRateLimiterTest < ActiveSupport::TestCase
  # 実時間を使わずに throttle のロジックを検証するためのフェイク単調時計。
  # sleeper 経由でのみ時刻が進むので、テストのアサーションが決定的になる。
  class FakeClock
    def initialize
      @now = 0.0
      @mutex = Mutex.new
    end

    def now
      @mutex.synchronize { @now }
    end

    def advance(seconds)
      @mutex.synchronize { @now += seconds }
    end
  end

  setup do
    ScrapingRateLimiter.reset!

    @fake_clock = FakeClock.new
    @sleep_calls = []
    @sleep_calls_mutex = Mutex.new

    fake_clock = @fake_clock
    sleep_calls = @sleep_calls
    sleep_calls_mutex = @sleep_calls_mutex

    ScrapingRateLimiter.clock = -> { fake_clock.now }
    ScrapingRateLimiter.sleeper = lambda do |seconds|
      sleep_calls_mutex.synchronize { sleep_calls << seconds }
      fake_clock.advance(seconds)
    end
  end

  teardown do
    ScrapingRateLimiter.reset!
  end

  test 'the first call for a host does not sleep' do
    with_env('SCRAPING_MIN_INTERVAL_DAM' => '1.0') do
      ScrapingRateLimiter.throttle('https://www.clubdam.com/a') { nil }
    end

    assert_empty @sleep_calls
  end

  test 'consecutive calls to the same host sleep for the remaining interval' do
    with_env('SCRAPING_MIN_INTERVAL_DAM' => '2.0') do
      ScrapingRateLimiter.throttle('https://www.clubdam.com/a') { nil }
      @fake_clock.advance(0.5)
      ScrapingRateLimiter.throttle('https://www.clubdam.com/b') { nil }
    end

    assert_equal [1.5], @sleep_calls
  end

  test 'a call after the interval has already elapsed does not sleep' do
    with_env('SCRAPING_MIN_INTERVAL_DAM' => '1.0') do
      ScrapingRateLimiter.throttle('https://www.clubdam.com/a') { nil }
      @fake_clock.advance(2.0)
      ScrapingRateLimiter.throttle('https://www.clubdam.com/b') { nil }
    end

    assert_empty @sleep_calls
  end

  test 'different hosts are throttled independently' do
    with_env('SCRAPING_MIN_INTERVAL_DAM' => '5.0', 'SCRAPING_MIN_INTERVAL_JOYSOUND' => '5.0') do
      ScrapingRateLimiter.throttle('https://www.clubdam.com/a') { nil }
      # 同一ホストへの2回目なので待たされる
      ScrapingRateLimiter.throttle('https://www.clubdam.com/b') { nil }
      # 別ホストへの初回呼び出しなので、DAM側の待機時間を引き継がない
      ScrapingRateLimiter.throttle('https://www.joysound.com/a') { nil }
    end

    assert_equal [5.0], @sleep_calls
  end

  test 'urls without a parsable host fall back to a shared default bucket without raising' do
    with_env('SCRAPING_MIN_INTERVAL_DEFAULT' => '4.0') do
      assert_nothing_raised do
        ScrapingRateLimiter.throttle('') { nil }
        ScrapingRateLimiter.throttle('not a valid url') { nil }
      end
    end

    assert_equal [4.0], @sleep_calls
  end

  test 'the return value of the block is returned' do
    result = with_env('SCRAPING_MIN_INTERVAL_DAM' => '1.0') do
      ScrapingRateLimiter.throttle('https://www.clubdam.com/a') { 'block result' }
    end

    assert_equal 'block result', result
  end

  test 'SCRAPING_MIN_INTERVAL_DAM controls the interval for dam hosts' do
    with_env('SCRAPING_MIN_INTERVAL_DAM' => '0.3') do
      ScrapingRateLimiter.throttle('https://www.clubdam.com/a') { nil }
      ScrapingRateLimiter.throttle('https://www.clubdam.com/b') { nil }
    end

    assert_equal [0.3], @sleep_calls
  end

  test 'SCRAPING_MIN_INTERVAL_JOYSOUND controls the interval for joysound hosts' do
    with_env('SCRAPING_MIN_INTERVAL_JOYSOUND' => '0.7') do
      ScrapingRateLimiter.throttle('https://www.joysound.com/a') { nil }
      ScrapingRateLimiter.throttle('https://www.joysound.com/b') { nil }
    end

    assert_equal [0.7], @sleep_calls
  end

  test 'concurrent calls to the same host are serialized and each waits the full interval' do
    with_env('SCRAPING_MIN_INTERVAL_DAM' => '1.0') do
      threads = Array.new(4) do
        Thread.new { ScrapingRateLimiter.throttle('https://www.clubdam.com/concurrent') { nil } }
      end
      threads.each(&:join)
    end

    assert_equal [1.0, 1.0, 1.0], @sleep_calls.sort
  end

  private

  def with_env(overrides)
    original = overrides.keys.index_with { |key| ENV.fetch(key, nil) }
    overrides.each { |key, value| ENV[key] = value }
    yield
  ensure
    original.each { |key, value| ENV[key] = value }
  end
end

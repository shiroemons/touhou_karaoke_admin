require 'test_helper'

class UrlCheckerTest < ActiveSupport::TestCase
  test 'check_url returns false for blank url' do
    assert_equal({ exists: false, error: 'Blank URL' }, UrlChecker.check_url(''))
  end

  test 'check_url returns successful result without retrying' do
    calls = 0

    with_stubbed_class_method(UrlChecker, :perform_check, lambda { |_uri|
      calls += 1
      { exists: true, status_code: 200, should_retry: false }
    }) do
      result = UrlChecker.check_url('https://example.com/song')

      assert_equal true, result[:exists]
      assert_equal 200, result[:status_code]
      assert_equal 1, calls
    end
  end

  test 'check_url returns 404 result without retrying' do
    calls = 0

    with_stubbed_class_method(UrlChecker, :perform_check, lambda { |_uri|
      calls += 1
      { exists: false, status_code: 404, should_retry: false }
    }) do
      result = UrlChecker.check_url('https://example.com/missing')

      assert_equal false, result[:exists]
      assert_equal 404, result[:status_code]
      assert_equal 1, calls
    end
  end

  test 'check_url retries transient failures and returns final success' do
    calls = 0

    with_stubbed_class_method(UrlChecker, :sleep, ->(_delay) {}) do
      with_stubbed_class_method(UrlChecker, :perform_check, lambda { |_uri|
        calls += 1
        next({ exists: nil, error: 'Timeout', should_retry: true }) if calls == 1

        { exists: true, status_code: 200, should_retry: false }
      }) do
        result = UrlChecker.check_url('https://example.com/retry', retries: 2)

        assert_equal true, result[:exists]
        assert_equal 200, result[:status_code]
        assert_equal 2, calls
      end
    end
  end

  test 'check_url returns retryable network error after exhausting retries' do
    calls = 0

    with_stubbed_class_method(UrlChecker, :sleep, ->(_delay) {}) do
      with_stubbed_class_method(UrlChecker, :perform_check, lambda { |_uri|
        calls += 1
        { exists: nil, error: 'Network error', should_retry: true }
      }) do
        result = UrlChecker.check_url('https://example.com/network-error', retries: 2)

        assert_nil result[:exists]
        assert_equal 'Network error after retries', result[:error]
        assert_equal true, result[:should_retry]
        assert_equal 3, calls
      end
    end
  end

  test 'url_exists? keeps retryable network errors as existing to prevent deletion' do
    with_stubbed_class_method(UrlChecker, :check_url, ->(_url) { { exists: nil, should_retry: true } }) do
      assert_equal true, UrlChecker.url_exists?('https://example.com/temporary-error')
    end
  end

  private

  def with_stubbed_class_method(klass, method_name, replacement)
    original = klass.method(method_name)
    klass.define_singleton_method(method_name, &replacement)
    yield
  ensure
    klass.define_singleton_method(method_name) do |*args, **kwargs, &block|
      original.call(*args, **kwargs, &block)
    end
  end
end

require 'test_helper'

class RetryableTest < ActiveSupport::TestCase
  class DummyRetryable
    include Retryable
  end

  # sleepとrandをスタブし、sleepに渡された秒数を記録する配列を返す
  def stub_sleep_and_rand(target, rand_value: 0)
    delays = []
    target.define_singleton_method(:sleep) { |seconds| delays << seconds }
    target.define_singleton_method(:rand) { rand_value }
    delays
  end

  test '指数的に増加するdelayでsleepし、max_delayに達したらクランプされる' do
    delays = stub_sleep_and_rand(DummyRetryable, rand_value: 0)
    attempt = 0

    DummyRetryable.with_retry(max_retries: 5, base_delay: 0.5, max_delay: 2.0) do
      attempt += 1
      raise Ferrum::TimeoutError if attempt <= 5
    end

    assert_equal [0.5, 1.0, 2.0, 2.0, 2.0], delays
  end

  test 'jitterはdelay〜delay*(1+jitter)の範囲に収まる' do
    delays = stub_sleep_and_rand(DummyRetryable, rand_value: 0.5)
    attempt = 0

    DummyRetryable.with_retry(max_retries: 1, base_delay: 1.0, max_delay: 10.0, jitter: 0.5) do
      attempt += 1
      raise Ferrum::TimeoutError if attempt <= 1
    end

    # delay = 1.0, jitter加算 = rand(=0.5) * jitter(0.5) * delay(1.0) = 0.25
    assert_equal [1.25], delays
    assert delays.first.between?(1.0, 1.0 * 1.5)
  end

  test 'Ferrum::DeadBrowserErrorはリトライ対象で、成功するまでretryする' do
    stub_sleep_and_rand(DummyRetryable)
    attempt = 0

    result = DummyRetryable.with_retry(max_retries: 3) do
      attempt += 1
      raise Ferrum::DeadBrowserError if attempt < 3

      'success'
    end

    assert_equal 'success', result
    assert_equal 3, attempt
  end

  test '最大リトライ回数を超えると元の例外がraiseされる' do
    stub_sleep_and_rand(DummyRetryable)

    error = assert_raises(Ferrum::TimeoutError) do
      DummyRetryable.with_retry(max_retries: 2) { raise Ferrum::TimeoutError }
    end
    assert_kind_of Ferrum::TimeoutError, error
  end

  test 'on_retryはリトライ回数分、(error, retry_count)を引数に呼ばれる' do
    stub_sleep_and_rand(DummyRetryable)
    calls = []
    attempt = 0

    DummyRetryable.with_retry(max_retries: 3, on_retry: ->(e, count) { calls << [e.class, count] }) do
      attempt += 1
      raise Ferrum::TimeoutError if attempt <= 2

      'ok'
    end

    assert_equal [[Ferrum::TimeoutError, 1], [Ferrum::TimeoutError, 2]], calls
  end

  test '非リトライ対象の例外はそのままraiseされる' do
    stub_sleep_and_rand(DummyRetryable)

    assert_raises(ArgumentError) do
      DummyRetryable.with_retry { raise ArgumentError, 'invalid' }
    end
  end

  test 'インスタンス版はclass_methods版のバックオフ処理へ委譲する' do
    delays = stub_sleep_and_rand(DummyRetryable, rand_value: 0)
    attempt = 0

    result = DummyRetryable.new.with_retry(max_retries: 2, base_delay: 0.5, max_delay: 8.0) do
      attempt += 1
      raise Ferrum::TimeoutError if attempt <= 1

      'done'
    end

    assert_equal 'done', result
    assert_equal [0.5], delays
  end
end

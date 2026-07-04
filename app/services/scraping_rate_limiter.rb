# frozen_string_literal: true

require "uri"

# 相手サイト（DAM/JOYSOUND）への負荷をスレッド数に依存させないための、ホスト別グローバルレートリミッタ。
#
# BrowserManager#visit のような、スクレイピングの実リクエスト発火点（choke point）から呼び出すことで、
# 並列スレッド数を増やしても相手サイトへの実効QPSをホスト単位で一定に保つ。BrowserManager 自体は
# スレッド毎に別インスタンスになるため、共有すべき状態（ホスト別の最終リクエスト時刻など）は
# このクラスのクラスレベル状態として持つ。
class ScrapingRateLimiter
  class << self
    attr_writer :clock, :sleeper

    # url のホストに対する最小リクエスト間隔を空けてから block を実行し、その戻り値を返す。
    #
    # 間隔保証（経過時間の確認・sleep・最終リクエスト時刻の更新）はホスト別Mutexの中で行うため、
    # 同一ホストへの呼び出しは直列化され、間隔が正しく保たれる。一方 block（実際のリクエスト）自体は
    # Mutexの外で実行する。次回呼び出しは更新済みの最終リクエスト時刻を見るため、この実装でも
    # 間隔保証は成立し、かつリクエスト処理中（wait_for_idle等で長時間かかりうる）に他ホストや
    # 後続呼び出しを不必要にブロックしない。シンプルさと正しさを両立できるこちらを採用した。
    def throttle(url)
      host = extract_host(url)

      mutex_for(host).synchronize do
        wait = min_interval_for(host) - elapsed_since_last_start(host)
        pause(wait) if wait.positive?
        last_started_at[host] = now
      end

      yield
    end

    # テスト用: ホスト別Mutex・最終リクエスト時刻・注入したclock/sleeperをすべてクリアする
    def reset!
      @host_mutexes = Concurrent::Map.new
      @last_started_at = Concurrent::Map.new
      @clock = nil
      @sleeper = nil
    end

    private

    def extract_host(url)
      URI.parse(url).host || "default"
    rescue StandardError
      "default"
    end

    def min_interval_for(host)
      case host
      when /dam/i
        ENV.fetch("SCRAPING_MIN_INTERVAL_DAM", "1.0").to_f
      when /joysound/i
        ENV.fetch("SCRAPING_MIN_INTERVAL_JOYSOUND", "1.0").to_f
      else
        ENV.fetch("SCRAPING_MIN_INTERVAL_DEFAULT", "1.0").to_f
      end
    end

    def elapsed_since_last_start(host)
      last = last_started_at[host]
      return Float::INFINITY unless last

      now - last
    end

    # ホスト毎のMutexを取得する。Concurrent::Mapのcompute_if_absentはアトミックなので、
    # 複数スレッドが同時に初回アクセスしても生成されるMutexはホストごとに1つだけになる。
    def mutex_for(host)
      host_mutexes.compute_if_absent(host) { Mutex.new }
    end

    def host_mutexes
      @host_mutexes ||= Concurrent::Map.new
    end

    def last_started_at
      @last_started_at ||= Concurrent::Map.new
    end

    def now
      clock.call
    end

    def pause(seconds)
      sleeper.call(seconds)
    end

    def clock
      @clock ||= -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
    end

    def sleeper
      @sleeper ||= ->(seconds) { Kernel.sleep(seconds) }
    end
  end
end

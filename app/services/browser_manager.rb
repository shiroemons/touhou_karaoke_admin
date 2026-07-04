# frozen_string_literal: true

# Webスクレイピング用のブラウザ管理を統一的に行うクラス
class BrowserManager
  DEFAULT_OPTIONS = {
    timeout: 10,
    window_size: [1440, 900],
    browser_options: { 'no-sandbox': nil, 'disk-cache-size': '1', 'disable-application-cache': nil }
  }.freeze

  attr_reader :browser, :options

  def initialize(custom_options = {}, persistent: false)
    @options = DEFAULT_OPTIONS.merge(custom_options)
    @browser = nil
    @persistent = persistent
  end

  # ブラウザを起動してブロックを実行
  # persistent: true の場合、ブラウザを終了せず再利用する（呼び出し側が close/restart で後始末する）
  def with_browser
    return yield(@browser) if @persistent && started?

    start_browser
    yield(@browser)
  ensure
    quit_browser unless @persistent
  end

  # ブラウザが起動済みかどうか
  def started?
    !@browser.nil?
  end

  # 永続モードかどうか
  def persistent?
    @persistent
  end

  # 永続ブラウザを明示的に終了する（プールの後始末用）
  def close
    quit_browser
  end

  # Chromeプロセスごと起動し直す（メモリ・キャッシュを完全に解放したい場合）
  def restart
    quit_browser
    start_browser
  end

  # cookie・localStorage・セッション状態、およびネットワークトラフィックの記録をクリアする
  # 未起動時は何もしない
  def reset_session
    return unless started?

    # browser.reset は Context を作り直して cookie 等をクリアする（Ferrum 標準API）
    @browser.reset
    @browser.network.clear(:traffic)
  end

  # ページにアクセスして安定するまで待機
  def visit(url, wait_duration: 1.0)
    raise 'Browser not started' unless @browser

    @browser.goto(url)
    @browser.network.wait_for_idle(duration: wait_duration, timeout: @options[:timeout])
  end

  # CSSセレクタで要素を取得
  def find(selector)
    raise 'Browser not started' unless @browser

    @browser.at_css(selector)
  end

  # CSSセレクタで複数要素を取得
  def find_all(selector)
    raise 'Browser not started' unless @browser

    @browser.css(selector)
  end

  # 現在のURL
  def current_url
    raise 'Browser not started' unless @browser

    @browser.current_url
  end

  # ネットワークトラフィックをクリア
  def clear_network_traffic
    raise 'Browser not started' unless @browser

    @browser.network.clear(:traffic)
  end

  private

  def start_browser
    @browser = Ferrum::Browser.new(**@options)
  end

  def quit_browser
    @browser&.quit
    @browser = nil
  end
end

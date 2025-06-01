# frozen_string_literal: true

# Webスクレイピング用のブラウザ管理を統一的に行うクラス
class BrowserManager
  DEFAULT_OPTIONS = {
    timeout: 10,
    window_size: [1440, 900],
    browser_options: { 'no-sandbox': nil }
  }.freeze

  attr_reader :browser, :options

  def initialize(custom_options = {})
    @options = DEFAULT_OPTIONS.merge(custom_options)
    @browser = nil
  end

  # ブラウザを起動してブロックを実行
  def with_browser
    start_browser
    yield(@browser)
  ensure
    quit_browser
  end

  # ページにアクセスして安定するまで待機
  def visit(url, wait_duration: 1.0)
    raise 'Browser not started' unless @browser

    @browser.goto(url)
    @browser.network.wait_for_idle(duration: wait_duration)
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

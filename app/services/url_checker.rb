# frozen_string_literal: true

# URLの存在確認を行うサービスクラス
#
# 概要:
#   HTTPのHEADリクエストを使用して、指定されたURLが有効かどうかを確認する
#   ネットワークエラーを考慮し、リトライ機能を実装
#
# 使用例:
#   result = UrlChecker.check_url("https://example.com/page")
#   # => { exists: true, status_code: 200 }
#   # => { exists: false, status_code: 404 }
#   # => { exists: nil, error: "Network error", should_retry: true }
#
# 処理内容:
#   1. URLが空でないかチェック
#   2. HTTPSまたはHTTPでHEADリクエストを送信（リトライ付き）
#   3. レスポンスコードが400未満なら存在すると判定
#   4. ネットワークエラーの場合はnilを返し、削除を防ぐ
#
# 主な用途:
#   - JOYSOUNDミュージックポストの期限切れURLの確認
#   - 無効になった楽曲ページの検出
class UrlChecker
  MAX_RETRIES = 3
  RETRY_DELAY = 2 # seconds
  TIMEOUT = 10 # seconds

  def self.url_exists?(url)
    result = check_url(url)
    # ネットワークエラーの場合はtrueを返して削除を防ぐ
    return true if result[:exists].nil? && result[:should_retry]
    
    result[:exists]
  end

  def self.check_url(url, retries: MAX_RETRIES)
    return { exists: false, error: "Blank URL" } if url.blank?

    uri = URI.parse(url)
    attempt = 0

    while attempt <= retries
      result = perform_check(uri)
      
      # 成功した場合、または明確な404の場合は結果を返す
      return result if result[:status_code] || !result[:should_retry]
      
      # リトライが必要な場合
      attempt += 1
      if attempt <= retries
        Rails.logger.warn("Retrying URL check for #{url} (attempt #{attempt}/#{retries})")
        sleep(RETRY_DELAY)
      end
    end

    # 全てのリトライが失敗した場合
    Rails.logger.error("URL check failed after #{retries} retries for #{url}")
    { exists: nil, error: "Network error after retries", should_retry: true }
  rescue StandardError => e
    Rails.logger.error("Unexpected error checking URL #{url}: #{e.message}")
    { exists: nil, error: e.message, should_retry: true }
  end

  private

  def self.perform_check(uri)
    request = Net::HTTP::Head.new(uri.request_uri)
    
    Net::HTTP.start(uri.host, uri.port, 
                    use_ssl: uri.scheme == 'https',
                    open_timeout: TIMEOUT,
                    read_timeout: TIMEOUT) do |http|
      response = http.request(request)
      status_code = response.code.to_i
      
      {
        exists: status_code < 400,
        status_code: status_code,
        should_retry: false
      }
    end
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    Rails.logger.warn("Timeout checking URL #{uri}: #{e.message}")
    { exists: nil, error: "Timeout", should_retry: true }
  rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError => e
    Rails.logger.warn("Network error checking URL #{uri}: #{e.message}")
    { exists: nil, error: "Network error", should_retry: true }
  rescue Net::HTTPError => e
    Rails.logger.error("HTTP error checking URL #{uri}: #{e.message}")
    { exists: nil, error: "HTTP error", should_retry: false }
  end
end

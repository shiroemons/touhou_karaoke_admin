# frozen_string_literal: true

# URLの存在確認を行うサービスクラス
#
# 概要:
#   HTTPのHEADリクエストを使用して、指定されたURLが有効かどうかを確認する
#
# 使用例:
#   UrlChecker.url_exists?("https://example.com/page")
#   # => true または false
#
# 処理内容:
#   1. URLが空でないかチェック
#   2. HTTPSまたはHTTPでHEADリクエストを送信
#   3. レスポンスコードが400未満なら存在すると判定
#   4. エラーが発生した場合は存在しないと判定
#
# 主な用途:
#   - JOYSOUNDミュージックポストの期限切れURLの確認
#   - 無効になった楽曲ページの検出
class UrlChecker
  def self.url_exists?(url)
    return false if url.blank?

    uri = URI.parse(url)
    request = Net::HTTP::Head.new(uri.request_uri)

    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
      response = http.request(request)
      response.code.to_i < 400
    end
  rescue StandardError => e
    Rails.logger.error("URL check failed for #{url}: #{e.message}")
    false
  end
end

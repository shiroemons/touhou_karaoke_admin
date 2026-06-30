# frozen_string_literal: true

module Admin
  module ErrorMessage
    DEFAULT_MESSAGE = '処理中にエラーが発生しました。詳細はログを確認してください。'

    module_function

    def user_facing(message, fallback: DEFAULT_MESSAGE, preserve_unknown: false)
      text = message.to_s.strip
      return fallback if text.blank?
      return text if text.match?(/[ぁ-んァ-ン一-龥]/)

      case text
      when /\ARequest failed:?\s*(\d+)\z/i
        "リクエストに失敗しました（HTTP #{Regexp.last_match(1)}）。"
      when /execution expired|timed out|timeout/i
        'タイムアウトしました。しばらくしてから再実行してください。'
      when /network error|connection failed|connection refused|failed to open tcp connection|getaddrinfo/i
        'ネットワーク接続に失敗しました。接続状況を確認してから再実行してください。'
      else
        preserve_unknown ? text : fallback
      end
    end
  end
end

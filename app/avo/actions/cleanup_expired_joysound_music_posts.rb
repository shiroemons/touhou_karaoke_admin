# frozen_string_literal: true

# 期限切れのJOYSOUNDミュージックポストをクリーンアップするAvoアクション
#
# 処理内容:
#   1. 配信期限（delivery_deadline_on）が過ぎているレコードを検索
#   2. 各レコードのURLが実際に存在するかHTTP HEADリクエストで確認
#   3. URLが404など無効な場合のみレコードを削除
#   4. 処理結果（確認件数、削除件数）を表示
#
# 使用サービス:
#   - JoysoundMusicPostCleaner: 実際のクリーンアップ処理
#   - UrlChecker: URLの存在確認
#
# 注意事項:
#   - この操作は取り消せません
#   - URLが一時的にアクセスできない場合も削除される可能性があります
class CleanupExpiredJoysoundMusicPosts < Avo::BaseAction
  self.name = "期限切れのJOYSOUNDミュージックポストをクリーンアップ"
  self.message = "配信期限が過ぎており、URLが存在しないレコードを削除します。この操作は元に戻せません。"
  self.confirm_button_label = "実行する"
  self.cancel_button_label = "キャンセル"

  # 個別レコードではなく、全体に対するアクションとして実行
  self.standalone = true

  def handle(**_args)
    cleaner = JoysoundMusicPostCleaner.new
    result = cleaner.cleanup_expired_records

    if result[:errors].any?
      error_message = "処理中にエラーが発生しました。詳細はログを確認してください。\n#{result[:errors].join("\n")}"
      failed(error_message)
    else
      succeed("クリーンアップが完了しました。確認件数: #{result[:checked]}件、削除件数: #{result[:deleted]}件")
    end
  end
end

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
  self.name = I18n.t('avo.action_translations.cleanup_expired_joysound_music_posts.name')
  self.message = I18n.t('avo.action_translations.cleanup_expired_joysound_music_posts.message')
  self.confirm_button_label = I18n.t('avo.action_translations.cleanup_expired_joysound_music_posts.confirm_button_label')
  self.cancel_button_label = I18n.t('avo.action_translations.cleanup_expired_joysound_music_posts.cancel_button_label')

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

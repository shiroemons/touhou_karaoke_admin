# frozen_string_literal: true

# JOYSOUNDミュージックポストの全メンテナンス処理を一括実行するAvoアクション
#
# 処理内容（実行順）:
#   1. cleanup_expired_records - 期限切れレコードの削除
#      - 配信期限切れかつURLが無効なJoysoundMusicPostを削除
#
#   2. fetch_songs_with_progress - 新規楽曲の取得
#      - 未登録楽曲を優先的にスクレイピング
#      - エラーハンドリングと進捗表示付き
#
#   3. refresh_songs_efficiently - 既存楽曲のURL確認
#      - 無効なURLの楽曲レコードを削除
#      - HTTP HEADリクエストで高速処理
#
#   4. update_delivery_deadlines_optimized - 配信期限の更新
#      - 楽曲の配信期限データを一括更新
#      - DBクエリ最適化済み
#
# 実行時間の目安:
#   - 小規模（〜1000件）: 1-2分
#   - 中規模（〜5000件）: 5-10分
#   - 大規模（10000件〜）: 15-30分
#
# 使用サービス:
#   - JoysoundMusicPostManager: 統合管理サービス
#   - 各種個別処理メソッド
#
# 注意事項:
#   - 処理中は他の操作を避けてください
#   - エラーが発生しても可能な限り処理を継続します
#   - 詳細なログは Rails.logger に出力されます
class PerformFullJoysoundMusicPostMaintenance < Avo::BaseAction
  self.name = I18n.t('avo.action_translations.perform_full_joysound_music_post_maintenance.name')
  self.message = I18n.t('avo.action_translations.perform_full_joysound_music_post_maintenance.message')
  self.confirm_button_label = I18n.t('avo.action_translations.perform_full_joysound_music_post_maintenance.confirm_button_label')
  self.cancel_button_label = I18n.t('avo.action_translations.perform_full_joysound_music_post_maintenance.cancel_button_label')
  self.standalone = true

  def handle(**_args)
    manager = JoysoundMusicPostManager.new
    results = manager.perform_full_maintenance

    summary = [
      "統合メンテナンスが完了しました:",
      "- 期限切れクリーンアップ: #{results[:cleanup][:deleted]}件削除",
      "- 楽曲取得: #{results[:fetch][:fetched]}件取得",
      "- URL確認: #{results[:refresh][:deleted]}件削除",
      "- 配信期限更新: #{results[:update_deadlines][:updated]}件更新"
    ].join("\n")

    total_errors = results.values.sum { |r| r[:errors]&.count || 0 }

    if total_errors.positive?
      failed("#{summary}\n\n#{total_errors}件のエラーが発生しました。詳細はログを確認してください。")
    else
      succeed(summary)
    end
    reload
  end
end

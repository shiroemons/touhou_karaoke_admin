# frozen_string_literal: true

# JOYSOUNDミュージックポストから楽曲データを取得するAvoアクション（改善版）
#
# 処理内容:
#   1. JoysoundMusicPostから優先度順にレコードを取得
#      - 未登録の楽曲（差分）を優先
#      - 配信期限が1ヶ月以内のものを次に処理
#   2. 各レコードに対してスクレイピングを実行
#   3. エラーハンドリングを強化し、個別エラーを記録
#   4. ParallelProcessorによる進捗表示
#
# 改善点:
#   - エラーが発生しても処理を継続
#   - 詳細なエラーログの記録
#   - 処理統計の表示（取得件数、エラー件数）
#
# 使用サービス:
#   - JoysoundMusicPostManager: 統合管理サービス
#   - Scrapers::JoysoundScraper: 実際のスクレイピング処理
class FetchJoysoundMusicPostSong < Avo::BaseAction
  self.name = I18n.t('avo.action_translations.fetch_joysound_music_post_song.name')
  self.message = I18n.t('avo.action_translations.fetch_joysound_music_post_song.message')
  self.standalone = true

  def handle(**_args)
    manager = JoysoundMusicPostManager.new
    result = manager.fetch_songs_with_progress

    if result[:errors].any?
      failed("取得処理が完了しましたが、#{result[:errors].count}件のエラーが発生しました。取得件数: #{result[:fetched]}件")
    else
      succeed("取得処理が正常に完了しました。取得件数: #{result[:fetched]}件、スキップ件数: #{result[:skipped]}件")
    end
    reload
  end
end

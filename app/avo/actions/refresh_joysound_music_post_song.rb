# frozen_string_literal: true

# JOYSOUNDミュージックポスト楽曲のURLを確認して無効なレコードを削除するAvoアクション（効率化版）
#
# 処理内容:
#   1. Song.music_postから全ての楽曲を取得
#   2. 各楽曲のURLに対してHTTP HEADリクエストで存在確認
#   3. 404エラーなどでアクセスできないURLの楽曲を削除
#   4. 処理結果（確認件数、削除件数）を表示
#
# 改善点（旧実装との比較）:
#   - ブラウザ起動が不要（Ferrum不使用）
#   - HTTP HEADリクエストで高速化（10倍以上高速）
#   - メモリ使用量の削減
#   - 並行処理が可能
#
# 使用サービス:
#   - JoysoundMusicPostManager: 統合管理サービス
#   - UrlChecker: URLの存在確認（HEADリクエスト）
#
# 注意事項:
#   - ネットワーク障害時は誤削除を防ぐため処理をスキップ
class RefreshJoysoundMusicPostSong < Avo::BaseAction
  self.name = "JOYSOUNDミュージックポスト楽曲の更新（効率化版）"
  self.message = "URLの存在確認により、無効な楽曲レコードを削除します。ブラウザを使わない高速処理です。"
  self.standalone = true

  def handle(**_args)
    manager = JoysoundMusicPostManager.new
    result = manager.refresh_songs_efficiently

    if result[:errors].any?
      failed("更新処理が完了しましたが、#{result[:errors].count}件のエラーが発生しました。削除件数: #{result[:deleted]}件")
    else
      succeed("更新処理が正常に完了しました。確認件数: #{result[:total_checked]}件、削除件数: #{result[:deleted]}件")
    end
    reload
  end
end

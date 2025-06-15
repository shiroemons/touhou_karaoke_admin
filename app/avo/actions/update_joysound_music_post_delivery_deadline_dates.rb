# frozen_string_literal: true

# JOYSOUNDミュージックポスト楽曲の配信期限を一括更新するAvoアクション（最適化版）
#
# 処理内容:
#   1. Song（music_post）とsong_with_joysound_utasukiが存在する楽曲を取得
#   2. JoysoundMusicPostのURL別配信期限データをハッシュで事前読み込み
#   3. 各楽曲のsong_with_joysound_utasuki.urlから対応する配信期限を検索
#   4. 配信期限が異なる場合のみ更新処理を実行
#
# 改善点（旧実装との比較）:
#   - N+1クエリ問題の解消（事前ハッシュ化）
#   - バッチ処理によるメモリ効率化（find_each使用）
#   - 不要な更新をスキップ（changed?チェック）
#   - DB接続の効率化
#
# データベース最適化:
#   - JoysoundMusicPost.pluckで必要なデータのみ取得
#   - includesによる関連データの事前読み込み
#   - find_eachによるバッチ処理（1000件ずつ）
#
# 使用サービス:
#   - JoysoundMusicPostManager: 統合管理サービス
class UpdateJoysoundMusicPostDeliveryDeadlineDates < Avo::BaseAction
  self.name = "JOYSOUNDミュージックポスト楽曲の配信期限を更新（最適化版）"
  self.message = "配信期限データを効率的に一括更新します。データベースクエリが最適化されています。"
  self.standalone = true

  def handle(**_args)
    manager = JoysoundMusicPostManager.new
    result = manager.update_delivery_deadlines_optimized

    if result[:errors].any?
      failed("更新処理が完了しましたが、#{result[:errors].count}件のエラーが発生しました。更新件数: #{result[:updated]}件")
    else
      succeed("更新処理が正常に完了しました。処理件数: #{result[:total_processed]}件、更新件数: #{result[:updated]}件")
    end
    reload
  end
end

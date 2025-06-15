# frozen_string_literal: true

# 楽曲と配信機種の重複関連付けを修正するスクリプト
#
# 実行方法:
#   docker compose run --rm web bin/rails r lib/fix_song_delivery_model_duplicates.rb
#
# 処理内容:
#   1. song_id + karaoke_delivery_model_idの重複組み合わせを検出
#   2. 各重複グループで最古のレコードを保持
#   3. その他の重複レコードを削除
#   4. 削除前後の統計情報を表示
#
# 安全性:
#   - トランザクション内で実行
#   - バックアップの確認を促す
#   - 各ステップの詳細ログ出力

puts "楽曲-配信機種関連付けの重複修正を開始します..."
puts "⚠️  この操作は不可逆です。事前にデータベースのバックアップを確認してください。"
puts ""

# 事前チェック：重複があるかどうか確認
duplicate_combinations = ActiveRecord::Base.connection.execute(<<~SQL)
  SELECT song_id, karaoke_delivery_model_id, COUNT(*) as duplicate_count
  FROM songs_karaoke_delivery_models
  GROUP BY song_id, karaoke_delivery_model_id
  HAVING COUNT(*) > 1
SQL

if duplicate_combinations.count == 0
  puts "✅ 重複は見つかりませんでした。修正の必要はありません。"
  exit
end

puts "📋 検出された重複:"
puts "  重複組数: #{duplicate_combinations.count}組"

total_records_before = SongsKaraokeDeliveryModel.count
redundant_records = 0
duplicate_combinations.each do |combination|
  duplicate_count = combination['duplicate_count'].to_i
  redundant_records += (duplicate_count - 1)
end

puts "  現在のレコード数: #{total_records_before}件"
puts "  削除予定レコード数: #{redundant_records}件"
puts "  修正後のレコード数: #{total_records_before - redundant_records}件"
puts ""

# 自動実行（Docker環境では確認プロンプトをスキップ）
puts "処理を自動実行します..."

# 統計情報を初期化
stats = {
  duplicate_groups_processed: 0,
  records_deleted: 0,
  errors: []
}

puts "\n🔧 重複修正開始..."

ActiveRecord::Base.transaction do
  duplicate_combinations.each do |combination|
    song_id = combination['song_id']
    karaoke_delivery_model_id = combination['karaoke_delivery_model_id']
    
    # 該当する全レコードを取得
    duplicate_records = SongsKaraokeDeliveryModel
                        .where(song_id: song_id, karaoke_delivery_model_id: karaoke_delivery_model_id)
                        .includes(:song, :karaoke_delivery_model)
                        .order(:created_at)

    song = duplicate_records.first&.song
    delivery_model = duplicate_records.first&.karaoke_delivery_model

    puts "  処理中: \"#{song&.title}\" × \"#{delivery_model&.name}\" (#{duplicate_records.count}件)"

    # 最古のレコードを保持、その他を削除
    records_to_keep = duplicate_records.first
    records_to_delete = duplicate_records[1..]

    puts "    保持: #{records_to_keep.id} (#{records_to_keep.created_at.strftime('%Y-%m-%d %H:%M:%S')})"

    records_to_delete.each do |record|
      puts "    削除: #{record.id} (#{record.created_at.strftime('%Y-%m-%d %H:%M:%S')})"
      record.destroy!
      stats[:records_deleted] += 1
    end

    stats[:duplicate_groups_processed] += 1
  rescue StandardError => e
    error_msg = "エラー: Song ID #{song_id} × DeliveryModel ID #{karaoke_delivery_model_id} - #{e.message}"
    puts "    ❌ #{error_msg}"
    stats[:errors] << error_msg
    raise e # トランザクションをロールバック
  end

  puts "\n📈 修正結果:"
  puts "  処理した重複組数: #{stats[:duplicate_groups_processed]}"
  puts "  削除したレコード数: #{stats[:records_deleted]}"

  if stats[:errors].any?
    puts "  エラー数: #{stats[:errors].size}"
    stats[:errors].each { |error| puts "    - #{error}" }
    raise "エラーが発生したため処理を中止します"
  end

  # 修正後の確認
  remaining_result = ActiveRecord::Base.connection.execute(<<~SQL)
    SELECT COUNT(*) as remaining_count
    FROM (
      SELECT song_id, karaoke_delivery_model_id
      FROM songs_karaoke_delivery_models
      GROUP BY song_id, karaoke_delivery_model_id
      HAVING COUNT(*) > 1
    ) as duplicates
  SQL
  remaining_duplicates = remaining_result.first['remaining_count'].to_i

  raise "修正後も#{remaining_duplicates}組の重複が残っています" if remaining_duplicates.positive?

  total_records_after = SongsKaraokeDeliveryModel.count
  puts "  修正前レコード数: #{total_records_before}件"
  puts "  修正後レコード数: #{total_records_after}件"
  puts "  削除されたレコード数: #{total_records_before - total_records_after}件"

  puts "\n✅ 修正完了！"
end

puts "\n🔍 修正後の確認:"
puts "  以下のコマンドで重複がないことを確認してください:"
puts "  docker compose run --rm web bin/rails r lib/check_song_delivery_model_duplicates.rb"

puts "\n💡 今後の重複防止:"
puts "  ユニーク制約を追加することを推奨します:"
puts "  docker compose run --rm web bin/rails r lib/add_unique_constraint_to_song_delivery_models.rb"

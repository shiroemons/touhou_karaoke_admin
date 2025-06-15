# frozen_string_literal: true

# 楽曲と配信機種の関連付けで重複がないかチェックするスクリプト
#
# 実行方法:
#   docker compose run --rm web bin/rails r lib/check_song_delivery_model_duplicates.rb
#
# 機能:
#   1. song_id + karaoke_delivery_model_idの組み合わせで重複をチェック
#   2. 重複がある場合は詳細を表示（楽曲名、配信機種名、重複数）
#   3. 重複解決の提案を表示
#
# 出力例:
#   重複が見つかりました: [楽曲名] × [配信機種名] - 3件
#   ID: uuid1, Created: 2024-01-01 10:00:00
#   ID: uuid2, Created: 2024-01-01 10:01:00
#   ID: uuid3, Created: 2024-01-01 10:02:00

puts "楽曲-配信機種関連付けの重複チェックを開始します..."

# song_id + karaoke_delivery_model_idでグループ化して重複を検出
puts "🔍 重複検出中..."

duplicate_groups = SongsKaraokeDeliveryModel
                   .select('song_id, karaoke_delivery_model_id, COUNT(*) as count')
                   .group(:song_id, :karaoke_delivery_model_id)
                   .having('COUNT(*) > 1')

if duplicate_groups.empty?
  puts "✅ 重複は見つかりませんでした。"
else
  puts "❌ #{duplicate_groups.count}組の重複が見つかりました:\n"

  total_duplicates = 0
  total_redundant_records = 0

  duplicate_groups.each do |group|
    # 該当する全レコードを取得
    duplicate_records = SongsKaraokeDeliveryModel
                        .where(song_id: group.song_id, karaoke_delivery_model_id: group.karaoke_delivery_model_id)
                        .includes(:song, :karaoke_delivery_model)
                        .order(:created_at)

    song = duplicate_records.first.song
    delivery_model = duplicate_records.first.karaoke_delivery_model

    puts "📋 楽曲: \"#{song.title}\" (#{song.karaoke_type})"
    puts "   配信機種: \"#{delivery_model.name}\""
    puts "   重複数: #{duplicate_records.count}件"

    duplicate_records.each_with_index do |record, index|
      marker = index.zero? ? "🟢 保持" : "🔴 削除候補"
      puts "   #{marker} ID: #{record.id}, Created: #{record.created_at.strftime('%Y-%m-%d %H:%M:%S')}"
    end

    puts ""
    total_duplicates += 1
    total_redundant_records += (duplicate_records.count - 1)
  end

  puts "📊 重複統計:"
  puts "  重複組数: #{total_duplicates}組"
  puts "  削除可能レコード数: #{total_redundant_records}件"
  puts "  削除後の総レコード数: #{SongsKaraokeDeliveryModel.count - total_redundant_records}件"

  puts "\n🔧 修復方法:"
  puts "  以下のコマンドを実行して重複を解決できます:"
  puts "  docker compose run --rm web bin/rails r lib/fix_song_delivery_model_duplicates.rb"
end

puts "\n📈 全体統計:"
total_associations = SongsKaraokeDeliveryModel.count
unique_associations = SongsKaraokeDeliveryModel.select('DISTINCT song_id, karaoke_delivery_model_id').count
total_songs = Song.count
total_delivery_models = KaraokeDeliveryModel.count

puts "  総関連付けレコード数: #{total_associations}件"
puts "  ユニークな関連付け数: #{unique_associations}件"
puts "  総楽曲数: #{total_songs}件"
puts "  総配信機種数: #{total_delivery_models}件"
puts "  平均関連付け数/楽曲: #{(total_associations.to_f / total_songs).round(2)}件" if total_songs.positive?

puts "\n✅ チェック完了"

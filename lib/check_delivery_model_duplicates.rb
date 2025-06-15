# frozen_string_literal: true

# JOYSOUNDの配信機種に重複がないかチェックするスクリプト
#
# 実行方法:
#   docker compose run --rm web bin/rails r lib/check_delivery_model_duplicates.rb
#
# 機能:
#   1. name + karaoke_typeの組み合わせで重複をチェック
#   2. 重複がある場合は詳細を表示
#   3. 重複の解決方法を提案
#
# 出力例:
#   重複が見つかりました: JOYSOUND MAX GO (JOYSOUND) - 2件
#   ID: uuid1, Order: 1, Created: 2024-01-01
#   ID: uuid2, Order: 2, Created: 2024-01-02

puts "配信機種の重複チェックを開始します..."

# 全ての配信機種を取得
all_models = KaraokeDeliveryModel.includes(:songs)

# name + karaoke_typeでグループ化
grouped_models = all_models.group_by { |model| [model.name, model.karaoke_type] }

# 重複を検出
duplicates = grouped_models.select { |_key, models| models.size > 1 }

if duplicates.empty?
  puts "✅ 重複は見つかりませんでした。"
else
  puts "❌ #{duplicates.size}組の重複が見つかりました:\n"

  duplicates.each do |(name, karaoke_type), models|
    puts "📋 #{name} (#{karaoke_type}) - #{models.size}件の重複"

    models.sort_by(&:created_at).each_with_index do |model, index|
      songs_count = model.songs.count
      puts "  #{index + 1}. ID: #{model.id}"
      puts "     Order: #{model.order}"
      puts "     Created: #{model.created_at.strftime('%Y-%m-%d %H:%M:%S')}"
      puts "     関連楽曲数: #{songs_count}件"
    end

    # 統合の提案
    oldest_model = models.min_by(&:created_at)
    newer_models = models - [oldest_model]
    total_songs = models.sum { |model| model.songs.count }

    puts "  💡 統合提案:"
    puts "     保持: #{oldest_model.id} (最古, #{oldest_model.songs.count}楽曲)"
    puts "     削除対象: #{newer_models.map(&:id).join(', ')}"
    puts "     移行予定楽曲数: #{newer_models.sum { |model| model.songs.count }}件"
    puts "     統合後楽曲数: #{total_songs}件"
    puts ""
  end

  puts "🔧 修復方法:"
  puts "  以下のコマンドを実行して重複を解決できます:"
  puts "  docker compose run --rm web bin/rails r lib/fix_delivery_model_duplicates.rb"
end

puts "\n📊 統計情報:"
puts "  総配信機種数: #{all_models.count}件"
puts "  ユニークな組み合わせ数: #{grouped_models.size}件"
puts "  JOYSOUND機種数: #{all_models.count { |m| m.karaoke_type == 'JOYSOUND' }}件"
puts "  DAM機種数: #{all_models.count { |m| m.karaoke_type == 'DAM' }}件"

puts "\n✅ チェック完了"

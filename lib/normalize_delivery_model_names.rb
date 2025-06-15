# frozen_string_literal: true

# 配信機種名の正規化スクリプト
#
# 実行方法:
#   docker compose run --rm web bin/rails r lib/normalize_delivery_model_names.rb
#
# 処理内容:
#   1. 全ての配信機種名を正規化（空白除去、全角/半角統一）
#   2. 正規化により重複が発生する場合は警告
#   3. 処理結果の詳細レポート
#
# 注意事項:
#   - 事前にバックアップを作成してください
#   - 正規化により重複が発生する場合は手動対応が必要です

puts "配信機種名の正規化を開始します..."

validator = DeliveryModelValidator.new

# 事前チェック: 正規化により重複が発生しないか確認
puts "🔍 事前チェック: 正規化により重複が発生しないか確認中..."

potential_duplicates = []
KaraokeDeliveryModel.find_each do |model|
  normalized_name = validator.normalize_name(model.name)
  next if normalized_name == model.name

  # 正規化後の名前で既存レコード（自分以外）があるかチェック
  existing = KaraokeDeliveryModel.where(name: normalized_name, karaoke_type: model.karaoke_type)
                                 .where.not(id: model.id)
                                 .first

  if existing
    potential_duplicates << {
      current: model,
      normalized_name:,
      existing:
    }
  end
end

if potential_duplicates.any?
  puts "⚠️  正規化により以下の重複が発生します:"
  potential_duplicates.each do |dup|
    puts "  現在: \"#{dup[:current].name}\" → \"#{dup[:normalized_name]}\""
    puts "  既存: \"#{dup[:existing].name}\" (ID: #{dup[:existing].id})"
    puts "  対象ID: #{dup[:current].id}"
    puts ""
  end

  puts "❌ 重複が発生するため、事前に以下のスクリプトを実行してください:"
  puts "  docker compose run --rm web bin/rails r lib/fix_delivery_model_duplicates.rb"
  exit 1
end

puts "✅ 重複は発生しません。正規化を実行します..."

# 確認プロンプト
print "続行しますか？ (yes/no): "
confirmation = $stdin.gets.chomp.downcase
unless confirmation == 'yes'
  puts "処理をキャンセルしました。"
  exit
end

# 正規化実行
puts "\n🔧 正規化実行中..."
updated_count = validator.normalize_existing_records

# DeliveryModelManagerのキャッシュをクリア
DeliveryModelManager.instance.clear_cache
puts "📦 DeliveryModelManagerのキャッシュをクリアしました"

puts "\n📊 正規化結果:"
puts "  更新されたレコード数: #{updated_count}件"

if updated_count.positive?
  puts "\n✅ 正規化完了！"
  puts "🔍 確認コマンド:"
  puts "  docker compose run --rm web bin/rails r lib/check_delivery_model_duplicates.rb"
else
  puts "\n✅ 正規化の必要なレコードはありませんでした。"
end

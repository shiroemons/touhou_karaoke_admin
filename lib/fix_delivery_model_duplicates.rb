# frozen_string_literal: true

# JOYSOUNDの配信機種の重複を修正するスクリプト
#
# 実行方法:
#   docker compose run --rm web bin/rails r lib/fix_delivery_model_duplicates.rb
#
# 処理内容:
#   1. 重複している配信機種を検出
#   2. 最古のレコードを保持対象として選択
#   3. 新しいレコードの関連楽曲を最古のレコードに移行
#   4. 重複レコードを削除
#   5. order値の再調整
#
# 安全性:
#   - トランザクション内で実行
#   - バックアップの確認を促す
#   - 各ステップの詳細ログ出力

puts "配信機種の重複修正を開始します..."
puts "⚠️  この操作は不可逆です。事前にデータベースのバックアップを確認してください。"
puts ""

# 確認プロンプト
print "続行しますか？ (yes/no): "
confirmation = $stdin.gets.chomp.downcase
unless confirmation == 'yes'
  puts "処理をキャンセルしました。"
  exit
end

# 統計情報を初期化
stats = {
  duplicates_found: 0,
  records_merged: 0,
  songs_migrated: 0,
  records_deleted: 0,
  errors: []
}

ActiveRecord::Base.transaction do
  # 全ての配信機種を取得
  all_models = KaraokeDeliveryModel.includes(:songs)

  # name + karaoke_typeでグループ化
  grouped_models = all_models.group_by { |model| [model.name, model.karaoke_type] }

  # 重複を検出
  duplicates = grouped_models.select { |_key, models| models.size > 1 }

  if duplicates.empty?
    puts "✅ 重複は見つかりませんでした。"
  else
    stats[:duplicates_found] = duplicates.size
    puts "📋 #{duplicates.size}組の重複を修正します...\n"

    duplicates.each do |(name, karaoke_type), models|
      puts "🔧 修正中: #{name} (#{karaoke_type})"

      # 最古のモデルを保持対象として選択
      target_model = models.min_by(&:created_at)
      duplicate_models = models - [target_model]

      puts "  保持: #{target_model.id} (#{target_model.created_at.strftime('%Y-%m-%d')})"
      puts "  削除対象: #{duplicate_models.size}件"

      # 各重複モデルの楽曲を移行
      duplicate_models.each do |duplicate_model|
        songs_count = duplicate_model.songs.count

        if songs_count.positive?
          puts "    楽曲移行: #{duplicate_model.id} → #{target_model.id} (#{songs_count}件)"

          # songs_karaoke_delivery_modelsテーブルのレコードを更新
          SongsKaraokeDeliveryModel
            .where(karaoke_delivery_model_id: duplicate_model.id)
            .update_all(karaoke_delivery_model_id: target_model.id)

          stats[:songs_migrated] += songs_count
        end

        # 重複モデルを削除
        puts "    削除: #{duplicate_model.id}"
        duplicate_model.destroy!
        stats[:records_deleted] += 1
      end

      stats[:records_merged] += 1
      puts "  ✅ 完了\n"
    rescue StandardError => e
      error_msg = "エラー: #{name} (#{karaoke_type}) - #{e.message}"
      puts "  ❌ #{error_msg}"
      stats[:errors] << error_msg
      raise e # トランザクションをロールバック
    end
  end

  # order値の再調整（acts_as_listが自動で行うが、念のため）
  puts "📊 order値の再調整..."
  %w[JOYSOUND DAM].each do |karaoke_type|
    models = KaraokeDeliveryModel.where(karaoke_type:).order(:order)
    models.each_with_index do |model, index|
      new_order = index + 1
      if model.order != new_order
        model.update!(order: new_order)
        puts "  #{model.name}: order #{model.order} → #{new_order}"
      end
    end
  end

  puts "\n📈 修正結果:"
  puts "  重複組数: #{stats[:duplicates_found]}"
  puts "  統合された機種: #{stats[:records_merged]}"
  puts "  移行楽曲数: #{stats[:songs_migrated]}"
  puts "  削除レコード数: #{stats[:records_deleted]}"

  if stats[:errors].any?
    puts "  エラー数: #{stats[:errors].size}"
    stats[:errors].each { |error| puts "    - #{error}" }
    raise "エラーが発生したため処理を中止します"
  end

  puts "\n✅ 修正完了！"

  # DeliveryModelManagerのキャッシュをクリア
  DeliveryModelManager.instance.clear_cache
  puts "📦 DeliveryModelManagerのキャッシュをクリアしました"
end

puts "\n🔍 修正後の確認:"
puts "  以下のコマンドで重複がないことを確認してください:"
puts "  docker compose run --rm web bin/rails r lib/check_delivery_model_duplicates.rb"

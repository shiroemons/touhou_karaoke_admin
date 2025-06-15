# frozen_string_literal: true

# 楽曲-配信機種関連付けにユニーク制約を追加するスクリプト
#
# 実行方法:
#   docker compose run --rm web bin/rails r lib/add_unique_constraint_to_song_delivery_models.rb
#
# 処理内容:
#   1. 重複データのチェック
#   2. 重複がある場合は事前修正を促す
#   3. 重複がない場合はマイグレーション実行
#   4. ユニーク制約の追加
#
# 注意事項:
#   - 重複データがある場合はマイグレーションが失敗します
#   - 事前にfix_song_delivery_model_duplicates.rbを実行してください

require 'English'
puts "楽曲-配信機種関連付けへのユニーク制約追加を開始します..."

# 1. 重複チェック
puts "🔍 重複データをチェック中..."

duplicate_groups = SongsKaraokeDeliveryModel
                   .group(:song_id, :karaoke_delivery_model_id)
                   .having('COUNT(*) > 1')
                   .select(:song_id, :karaoke_delivery_model_id)

if duplicate_groups.any?
  puts "❌ #{duplicate_groups.count}組の重複が見つかりました。"
  puts "   ユニーク制約を追加する前に重複を解決する必要があります。"
  puts ""
  puts "🔧 重複解決手順:"
  puts "  1. 重複を確認: docker compose run --rm web bin/rails r lib/check_song_delivery_model_duplicates.rb"
  puts "  2. 重複を修正: docker compose run --rm web bin/rails r lib/fix_song_delivery_model_duplicates.rb"
  puts "  3. このスクリプトを再実行"
  exit 1
end

puts "✅ 重複は見つかりませんでした。"

# 2. マイグレーション実行
puts "\n🔧 ユニーク制約を追加中..."

begin
  # マイグレーション実行
  system("docker compose run --rm web bin/rails db:migrate")

  if $CHILD_STATUS.success?
    puts "✅ ユニーク制約の追加が完了しました！"

    # 3. 制約が正しく追加されたか確認
    puts "\n🔍 制約の確認中..."

    # データベースから制約を確認
    result = ActiveRecord::Base.connection.execute(<<~SQL.squish)
      SELECT indexname, indexdef#{' '}
      FROM pg_indexes#{' '}
      WHERE tablename = 'songs_karaoke_delivery_models'#{' '}
      AND indexdef LIKE '%UNIQUE%'
    SQL

    if result.any?
      puts "✅ ユニーク制約が正常に追加されました:"
      result.each do |row|
        puts "  - #{row['indexname']}: #{row['indexdef']}"
      end
    else
      puts "⚠️  ユニーク制約の確認に失敗しました。手動で確認してください。"
    end

    puts "\n📊 現在の統計:"
    total_associations = SongsKaraokeDeliveryModel.count
    unique_associations = SongsKaraokeDeliveryModel.select('DISTINCT song_id, karaoke_delivery_model_id').count

    puts "  総関連付けレコード数: #{total_associations}件"
    puts "  ユニークな関連付け数: #{unique_associations}件"

    if total_associations == unique_associations
      puts "  ✅ すべての関連付けがユニークです"
    else
      puts "  ⚠️  不整合があります (#{total_associations - unique_associations}件の重複)"
    end

  else
    puts "❌ マイグレーションが失敗しました。"
    puts "   エラーの詳細はログを確認してください。"
    exit 1
  end
rescue StandardError => e
  puts "❌ エラーが発生しました: #{e.message}"
  exit 1
end

puts "\n🎉 作業完了！"
puts "\n💡 今後の使用方法:"
puts "  楽曲と配信機種の関連付けを作成する際は、以下のメソッドを使用してください:"
puts "  SongsKaraokeDeliveryModel.find_or_create_association(song_id, delivery_model_id)"
puts "  SongsKaraokeDeliveryModel.create_associations_safely(song_id, delivery_model_ids)"

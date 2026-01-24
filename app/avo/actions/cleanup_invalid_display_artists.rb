# frozen_string_literal: true

require 'csv'

# 無効なDisplayArtistをクリーンアップするAvoアクション
#
# 処理内容:
#   1. 全てのDisplayArtistレコードを対象に検証
#   2. 各レコードのURLが実際に存在するかHTTP HEADリクエストで確認
#   3. URLが404など無効な場合のみレコードを削除
#   4. 関連するsongsがあるレコードは削除をスキップ
#   5. 処理結果（確認件数、無効URL件数、削除件数）を表示
#   6. 削除されたレコードがある場合、TSVファイルとしてダウンロード
#
# 使用サービス:
#   - DisplayArtistUrlValidator: 実際の検証・削除処理
#   - UrlChecker: URLの存在確認
#
# 注意事項:
#   - この操作は取り消せません
#   - URLが一時的にアクセスできない場合も削除される可能性があります
#   - 関連するsongsがあるレコードは削除されません
class CleanupInvalidDisplayArtists < Avo::BaseAction
  self.name = "無効なDisplayArtistを削除"
  self.message = "URLが無効なアーティストを検証し、削除します。※関連するsongsがあるレコードは削除されません。"
  self.confirm_button_label = "検証して削除"
  self.cancel_button_label = "キャンセル"

  # 個別レコードではなく、全体に対するアクションとして実行
  self.standalone = true
  self.may_download_file = true

  def handle(**_args)
    validator = DisplayArtistUrlValidator.new(delete_invalid: true)
    result = validator.validate_all

    if result[:errors].any?
      error_message = "処理中にエラーが発生しました。詳細はログを確認してください。\n#{result[:errors].join("\n")}"
      failed(error_message)
    elsif result[:deleted_records].any?
      tsv_data = generate_tsv(result[:deleted_records])
      download tsv_data, 'deleted_display_artists.tsv'
    else
      succeed(build_summary(result))
    end
  end

  private

  def generate_tsv(deleted_records)
    ::CSV.generate(col_sep: "\t") do |csv|
      csv << %w[id name karaoke_type url]
      deleted_records.each do |record|
        csv << [record[:id], record[:name], record[:karaoke_type], record[:url]]
      end
    end
  end

  def build_summary(result)
    messages = [
      "検証が完了しました。",
      "確認件数: #{result[:checked]}件",
      "無効URL: #{result[:invalid]}件",
      "削除件数: #{result[:deleted]}件"
    ]

    skipped_count = result[:invalid] - result[:deleted]
    messages << "※#{skipped_count}件は関連するsongsがあるため削除されませんでした。" if skipped_count.positive?

    messages.join("\n")
  end
end

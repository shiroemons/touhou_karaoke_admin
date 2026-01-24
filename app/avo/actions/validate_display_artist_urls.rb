# frozen_string_literal: true

require 'csv'

# DisplayArtistのURL検証を行うAvoアクション
#
# 処理内容:
#   1. 全DisplayArtistレコードのURLを検証
#   2. URLが有効かどうかをHTTPリクエストで確認
#   3. 無効なURLがある場合、TSVファイルとしてダウンロード
#
# 使用サービス:
#   - DisplayArtistUrlValidator: URL検証処理
#
# 注意事項:
#   - このアクションは検証のみで、削除は行いません
#   - 一時的なネットワーク障害でも無効と判定される場合があります
class ValidateDisplayArtistUrls < Avo::BaseAction
  self.name = "DisplayArtistのURL検証"
  self.message = "アーティストURLが有効かどうかを確認します。無効なURLはTSVファイルでダウンロードされます。"
  self.confirm_button_label = "検証する"
  self.cancel_button_label = "キャンセル"

  # 個別レコードではなく、全体に対するアクションとして実行
  self.standalone = true
  self.may_download_file = true

  def handle(**_args)
    validator = DisplayArtistUrlValidator.new(delete_invalid: false)
    result = validator.validate_all

    if result[:errors].any?
      error_message = "処理中にエラーが発生しました。詳細はログを確認してください。\n#{result[:errors].join("\n")}"
      failed(error_message)
    elsif result[:invalid_records].empty?
      succeed("URL検証が完了しました。確認件数: #{result[:checked]}件、無効なURLはありませんでした。")
    else
      tsv_data = generate_tsv(result[:invalid_records])
      download tsv_data, 'invalid_display_artists.tsv'
    end
  end

  private

  def generate_tsv(invalid_records)
    ::CSV.generate(col_sep: "\t") do |csv|
      csv << %w[id name karaoke_type url]
      invalid_records.each do |record|
        csv << [
          record[:id],
          record[:name],
          record[:karaoke_type],
          record[:url]
        ]
      end
    end
  end
end

# frozen_string_literal: true

require 'csv'

# 関連なしDisplayArtistをクリーンアップするAvoアクション
#
# 処理内容:
#   1. songsが紐づいていないDisplayArtistレコードを検索
#   2. 該当レコードを削除
#   3. 削除されたレコードがある場合、TSVファイルとしてダウンロード
#
# 注意事項:
#   - この操作は取り消せません
class CleanupOrphanDisplayArtists < Avo::BaseAction
  self.name = "関連なしDisplayArtistを削除"
  self.message = "songsが紐づいていないDisplayArtistを削除します。削除されたレコードはTSVファイルでダウンロードできます。"
  self.confirm_button_label = "削除する"
  self.cancel_button_label = "キャンセル"

  # 個別レコードではなく、全体に対するアクションとして実行
  self.standalone = true
  self.may_download_file = true

  def handle(**_args)
    orphan_display_artists = DisplayArtist.where.missing(:songs)

    if orphan_display_artists.empty?
      succeed("削除対象のレコードはありませんでした")
      return
    end

    deleted_records = collect_record_info(orphan_display_artists)

    # destroy を使用して dependent: :destroy コールバックを発火させる
    # delete_all はコールバックをバイパスするため、外部キー制約違反が発生する
    orphan_display_artists.find_each(&:destroy)

    tsv_data = generate_tsv(deleted_records)
    download tsv_data, 'deleted_orphan_display_artists.tsv'
  end

  private

  def collect_record_info(records)
    records.map do |record|
      {
        id: record.id,
        name: record.name,
        karaoke_type: record.karaoke_type,
        url: record.url
      }
    end
  end

  def generate_tsv(deleted_records)
    ::CSV.generate(col_sep: "\t") do |csv|
      csv << %w[id name karaoke_type url]
      deleted_records.each do |record|
        csv << [record[:id], record[:name], record[:karaoke_type], record[:url]]
      end
    end
  end
end

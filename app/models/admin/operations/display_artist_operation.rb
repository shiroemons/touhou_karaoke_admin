require 'csv'

module Admin
  module Operations
    class DisplayArtistOperation < BaseOperation
      DISPLAY_ARTIST_EXPORT_COLUMNS = %w[id name karaoke_type url].freeze

      def initialize(params:)
        super()
        @params = params
      end

      def validate_display_artist_urls(progress: nil)
        result = DisplayArtistUrlValidator.new(delete_invalid: false, progress:).validate_all

        raise StandardError, result[:errors].join("\n") if result[:errors].any?

        if result[:invalid_records].empty?
          message("URL検証が完了しました。確認件数: #{result[:checked]}件、無効なURLはありませんでした。")
        else
          download(generate_display_artists_tsv(result[:invalid_records]), 'invalid_display_artists.tsv')
        end
      end

      def cleanup_invalid_display_artists(progress: nil)
        dry_run = dry_run?
        result = DisplayArtistUrlValidator.new(delete_invalid: true, dry_run:, progress:).validate_all

        raise StandardError, result[:errors].join("\n") if result[:errors].any?

        if result[:deleted_records].any?
          filename = dry_run ? 'preview_deleted_display_artists.tsv' : 'deleted_display_artists.tsv'
          download(generate_display_artists_tsv(result[:deleted_records]), filename)
        else
          skipped_count = result[:invalid] - result[:deleted]
          summary = destructive_summary(dry_run, "検証が完了しました。確認件数: #{result[:checked]}件、無効URL: #{result[:invalid]}件、#{deletion_count_label(dry_run)}: #{result[:deleted]}件")
          summary += "。#{skipped_count}件は関連するsongsがあるため削除対象外です。" if skipped_count.positive?
          message(summary)
        end
      end

      def cleanup_orphan_display_artists(progress: nil)
        records = DisplayArtist.where.missing(:songs)
        return message('削除対象のレコードはありませんでした。') if records.empty?

        export_tsv = ActiveModel::Type::Boolean.new.cast(@params.dig(:operation_fields, :export_tsv))
        dry_run = dry_run?
        total_count = records.count
        status = dry_run ? '孤立アーティスト確認中' : '孤立アーティスト削除中'
        label = dry_run ? '楽曲が紐づいていないアーティストを確認しています' : '楽曲が紐づいていないアーティストを削除しています'
        progress&.call(percentage: 8, status:, label:, detail: "処理済み: 0/#{total_count}件", current: 0, total: total_count)
        deleted_records = records.map do |record|
          {
            id: record.id,
            name: record.name,
            karaoke_type: record.karaoke_type,
            url: record.url
          }
        end
        records.find_each.with_index(1) do |record, index|
          record.destroy! unless dry_run
          next unless (index % 10).zero? || index == total_count

          progress&.call(
            percentage: (8 + (88 * (index.to_f / total_count))).floor.clamp(8, 96),
            status:,
            label:,
            detail: "処理済み: #{index}/#{total_count}件",
            current: index,
            total: total_count
          )
        end

        return download(generate_display_artists_tsv(deleted_records), dry_run ? 'preview_deleted_orphan_display_artists.tsv' : 'deleted_orphan_display_artists.tsv') if export_tsv

        action = dry_run ? '削除対象を確認しました' : '孤立アーティストを削除しました'
        message("#{action}。#{deletion_count_label(dry_run)}: #{deleted_records.size}件。TSVは出力していません。")
      end

      private

      def generate_display_artists_tsv(records)
        CSV.generate(col_sep: "\t") do |csv|
          csv << DISPLAY_ARTIST_EXPORT_COLUMNS
          records.each do |record|
            csv << [record[:id], record[:name], record[:karaoke_type], record[:url]]
          end
        end
      end

      def dry_run?
        ActiveModel::Type::Boolean.new.cast(@params.dig(:operation_fields, :dry_run))
      end

      def destructive_summary(dry_run, text)
        dry_run ? "プレビューのみ実行しました。DBは変更していません。#{text}" : text
      end

      def deletion_count_label(dry_run)
        dry_run ? '削除予定件数' : '削除件数'
      end
    end
  end
end

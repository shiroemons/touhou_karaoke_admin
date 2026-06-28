# frozen_string_literal: true

module Admin
  module Resources
    module DisplayArtistResources
      private

      def display_artist
        resource(
          key: :display_artist,
          model: DisplayArtist,
          label: 'アーティスト',
          title: ->(record) { "[#{record.karaoke_type}] #{record.name}" },
          includes: %i[circles songs],
          order: { created_at: :desc },
          search: { name_cont: :q },
          filters: [
            karaoke_type_filter,
            association_presence_filter(:circles, label: 'サークル', association: :circles),
            association_presence_filter(:songs, label: '曲', association: :songs),
            presence_filter(:name_reading, label: '読み', present_label: '読みあり', blank_label: '読みなし')
          ],
          fields: [
            field(:circles, label: 'サークル', show: false, form: false, helper: ->(record) { record.circles.map(&:name).join('、') }),
            field(:circle_ids, label: 'サークル', type: :has_many_select, index: false, show: false, form: false, options: -> { Circle.order(:name).pluck(:name, :id) }),
            field(:karaoke_type, label: 'カラオケ種別', readonly: true, sortable: true),
            field(:name, label: 'アーティスト名', readonly: true, sortable: true),
            field(:name_reading, label: 'アーティスト名読み', sortable: true),
            field(:url, label: 'URL', type: :url, sortable: true)
          ],
          associations: %i[circles songs dam_songs],
          operations: [
            operation('DAMアーティスト読みを補完', key: :fetch_dam_artist, method_name: :fill_dam_artist_readings, group: '外部取得', async: true, confirmation: '外部サイトへアクセスしてDAMアーティスト読みを補完します。実行しますか？'),
            operation('JOYSOUNDアーティスト読みを補完', key: :fetch_joysound_artist, method_name: :fill_joysound_artist_readings, group: '外部取得', async: true, confirmation: '外部サイトへアクセスしてJOYSOUNDアーティスト読みを補完します。実行しますか？'),
            operation('うたスキアーティストを登録', key: :fetch_joysound_music_post_artist, method_name: :register_joysound_music_post_artists, group: '外部取得', async: true, confirmation: '外部サイトへアクセスしてうたスキアーティストを登録します。実行しますか？'),
            operation('URLを検証', handler: :validate_display_artist_urls, group: '検証・削除', confirmation: 'アーティストURLを検証します。実行しますか？'),
            operation(
              '無効なアーティストを削除',
              handler: :cleanup_invalid_display_artists,
              group: '検証・削除',
              confirmation: 'URLが無効なアーティストを削除します。実行しますか？',
              inputs: [
                { name: :dry_run, label: 'プレビューのみ', description: '削除せず対象をTSVで確認する', type: :checkbox, checked: true, required: false }
              ]
            ),
            operation(
              '孤立アーティストを削除',
              handler: :cleanup_orphan_display_artists,
              group: '検証・削除',
              confirmation: '楽曲が紐づいていないアーティストを削除します。実行しますか？',
              inputs: [
                { name: :dry_run, label: 'プレビューのみ', description: '削除せず対象を確認する', type: :checkbox, checked: true, required: false },
                { name: :export_tsv, label: '削除結果TSV', description: '削除したアーティストをTSVで出力する', type: :checkbox, checked: true, required: false }
              ]
            )
          ],
          strong_parameters: [:name_reading, :url, { circle_ids: [] }]
        )
      end
    end
  end
end

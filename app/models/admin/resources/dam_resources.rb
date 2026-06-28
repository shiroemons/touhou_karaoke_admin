# frozen_string_literal: true

module Admin
  module Resources
    module DamResources
      private

      def dam_song
        resource(
          key: :dam_song,
          model: DamSong,
          label: 'DAM楽曲',
          title: ->(record) { "[#{record.display_artist&.name}] #{record.title}" },
          includes: [:display_artist],
          order: { created_at: :desc },
          search: { display_artist_name_cont: :q, title_cont: :q, m: 'or' },
          filters: [
            artist_circle_filter
          ],
          fields: [
            field(:display_artist, label: 'アーティスト', type: :belongs_to, form: false, link: true, sortable: true),
            field(:display_artist_id, label: 'アーティスト', type: :belongs_to_select, index: false, show: false, options: -> { DisplayArtist.dam.order(:name).limit(500).pluck(:name, :id) }),
            field(:title, label: 'タイトル', readonly: true, sortable: true, link: true),
            field(:url, label: 'URL', type: :url, readonly: true, sortable: true)
          ],
          operations: [
            operation('DAM候補一覧を取得', key: :fetch_dam_touhou_songs, method_name: :fetch_dam_candidate_songs, group: '外部取得', async: true, estimated_seconds: 40, confirmation: '外部サイトへアクセスしてDAM候補一覧を取得します。実行しますか？'),
            operation('DAM楽曲URLから候補を追加', handler: :fetch_dam_song, group: 'URL指定取得', async: true, confirmation: '指定URLからDAM候補を追加します。実行しますか？', inputs: [{ name: :dam_song_url, label: 'DAM楽曲URL', type: :text, placeholder: Constants::Karaoke::Dam::SONG_URL }])
          ]
        )
      end

      def dam_artist_url
        resource(
          key: :dam_artist_url,
          model: DamArtistUrl,
          label: 'DAMアーティストURL',
          title: :url,
          search: { url_cont: :q },
          filters: [
            dam_artist_url_registration_filter
          ],
          fields: [
            field(:url, label: 'URL', type: :url, link: true, sortable: true)
          ]
        )
      end

      def song_with_dam_ouchikaraoke
        resource(
          key: :song_with_dam_ouchikaraoke,
          model: SongWithDamOuchikaraoke,
          label: 'DAMおうちカラオケ',
          title: :url,
          navigation: false,
          includes: [:song],
          filters: [
            association_exact_filter(:karaoke_type, label: 'カラオケ種別', association: :song, column: :karaoke_type, options: karaoke_type_value_options)
          ],
          fields: [
            field(:song, label: 'カラオケ配信曲', type: :belongs_to, form: false, link: true, sortable: true),
            field(:song_id, label: 'カラオケ配信曲', type: :belongs_to_select, index: false, show: false, readonly: true, options: -> { Song.order(:title).limit(500).pluck(:title, :id) }),
            field(:url, label: 'URL', type: :url, readonly: true, sortable: true)
          ]
        )
      end
    end
  end
end

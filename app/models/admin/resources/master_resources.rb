# frozen_string_literal: true

module Admin
  module Resources
    module MasterResources
      private

      def original
        resource(
          key: :original,
          model: Original,
          label: '原作',
          title: :title,
          search: { title_cont: :q },
          filters: [
            exact_filter(:original_type, label: '種別', options: Original.original_types.keys.index_with(&:itself))
          ],
          fields: [
            field(:code, label: 'コード', form: true, readonly: true, sortable: true),
            field(:title, label: '作品名', readonly: true, sortable: true),
            field(:short_title, label: '短縮タイトル', readonly: true, sortable: true),
            field(:original_type, label: '種別', type: :badge, readonly: true, options: Original.original_types.keys),
            field(:series_order, label: 'シリーズ順', type: :number, readonly: true, sortable: true)
          ],
          associations: %i[original_songs]
        )
      end

      def original_song
        resource(
          key: :original_song,
          model: OriginalSong,
          label: '原曲',
          title: ->(record) { "[#{record.original&.short_title}] #{record.title}" },
          includes: [:original],
          order: { code: :asc },
          search: { title_cont: :q },
          filters: [
            boolean_filter(:is_duplicate, label: '重複フラグ', true_label: '重複のみ', false_label: '重複以外'),
            association_exact_filter(:original_type, label: '原作種別', association: :original, column: :original_type, options: Original.original_types.keys.index_with(&:itself))
          ],
          fields: [
            field(:code, label: 'コード', form: true, readonly: true, sortable: true),
            field(:original, label: '原作', type: :belongs_to, form: false, link: true, sortable: true),
            field(:original_code, label: '原作', type: :belongs_to_select, index: false, show: false, readonly: true, options: -> { Original.order(:code).pluck(:title, :code) }),
            field(:title, label: '原曲名', readonly: true, sortable: true),
            field(:composer, label: '作曲者', readonly: true, sortable: true),
            field(:track_number, label: 'トラック番号', type: :number, readonly: true, sortable: true),
            field(:is_duplicate, label: '重複フラグ', type: :boolean, readonly: true, sortable: true)
          ],
          associations: %i[songs]
        )
      end

      def karaoke_delivery_model
        resource(
          key: :karaoke_delivery_model,
          model: KaraokeDeliveryModel,
          label: '配信機種',
          title: :name,
          order: { order: :asc },
          search: { name_cont: :q },
          filters: [delivery_karaoke_type_filter],
          fields: [
            field(:name, label: '機種名', sortable: true),
            field(:karaoke_type, label: 'カラオケ種別', type: :select, sortable: true, options: %w[DAM JOYSOUND]),
            field(:order, label: '表示順', type: :number, sortable: true)
          ],
          operations: [
            operation('上へ移動', method_name: :move_higher, scope: :member, group: '並び替え'),
            operation('下へ移動', method_name: :move_lower, scope: :member, group: '並び替え'),
            operation('先頭へ移動', method_name: :move_to_top, scope: :member, group: '並び替え'),
            operation('末尾へ移動', method_name: :move_to_bottom, scope: :member, group: '並び替え')
          ]
        )
      end

      def circle
        resource(
          key: :circle,
          model: Circle,
          label: 'サークル',
          title: :name,
          includes: [:display_artists],
          search: { name_cont: :q },
          filters: [
            association_presence_filter(:display_artists, label: 'アーティスト', association: :display_artists),
            association_presence_filter(:songs, label: '曲', association: :songs)
          ],
          fields: [
            field(:name, label: 'サークル名', sortable: true, link: true),
            field(:display_artists_count, label: 'アーティスト数', type: :number, form: false, sortable: true, count_association: :display_artists),
            field(:songs_count, label: '曲数', type: :number, form: false, sortable: true, count_association: :songs)
          ],
          associations: %i[display_artists songs]
        )
      end
    end
  end
end

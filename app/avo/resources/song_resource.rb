class SongResource < Avo::BaseResource
  self.title = :title
  self.translation_key = 'avo.resource_translations.song'
  self.includes = %i[display_artist
                     karaoke_delivery_models
                     original_songs
                     song_with_dam_ouchikaraoke
                     song_with_joysound_utasuki]
  self.search_query = lambda {
    scope.ransack(title_cont: params[:q], m: "or").result(distinct: false)
  }
  self.resolve_query_scope = lambda { |model_class:|
    model_class.order(created_at: :desc)
  }

  field :id, as: :id, name: 'ID', hide_on: [:index]
  field :karaoke_type, as: :text, name: 'カラオケ種別', readonly: true, sortable: true
  field :song_number, as: :text, name: '曲番号', readonly: true, hide_on: [:index]
  field :display_artist, as: :belongs_to, name: 'アーティスト', readonly: true, sortable: ->(query, direction) { query.order("display_artists.name #{direction}") }
  field :title, as: :text, name: 'タイトル', readonly: true, sortable: true, link_to_resource: true
  field :title_reading, as: :text, name: 'タイトル読み', readonly: true, hide_on: [:index]
  field :url, as: :text, name: 'URL', readonly: true, format_using: -> { link_to(value, value, target: "_blank", rel: "noopener") }, hide_on: %i[index new edit]

  field :touhou?, as: :text, name: 'touhou', only_on: [:index], format_using: -> { value.present? ? '✅' : '' }, index_text_align: :center
  field :youtube_url, as: :text, name: 'YouTube URL', only_on: [:index], format_using: -> { value.present? ? '✅' : '' }, index_text_align: :center
  field :nicovideo_url, as: :text, name: 'ニコニコ動画 URL', only_on: [:index], format_using: -> { value.present? ? '✅' : '' }, index_text_align: :center
  field :apple_music_url, as: :text, name: 'Apple Music URL', only_on: [:index], format_using: -> { value.present? ? '✅' : '' }, index_text_align: :center
  field :youtube_music_url, as: :text, name: 'YouTube Music URL', only_on: [:index], format_using: -> { value.present? ? '✅' : '' }, index_text_align: :center
  field :spotify_url, as: :text, name: 'Spotify URL', only_on: [:index], format_using: -> { value.present? ? '✅' : '' }, index_text_align: :center
  field :line_music_url, as: :text, name: 'LINE MUSIC URL', only_on: [:index], format_using: -> { value.present? ? '✅' : '' }, index_text_align: :center

  field :youtube_url, as: :text, name: 'YouTube URL', only_on: %i[new edit]
  field :nicovideo_url, as: :text, name: 'ニコニコ動画 URL', only_on: %i[new edit]
  field :apple_music_url, as: :text, name: 'Apple Music URL', only_on: %i[new edit]
  field :youtube_music_url, as: :text, name: 'YouTube Music URL', only_on: %i[new edit]
  field :spotify_url, as: :text, name: 'Spotify URL', only_on: %i[new edit]
  field :line_music_url, as: :text, name: 'LINE MUSIC URL', only_on: %i[new edit]

  field :youtube_url, as: :text, name: 'YouTube URL', hide_on: %i[index new edit], format_using: -> { link_to(value, value, target: "_blank", rel: "noopener") }
  field :nicovideo_url, as: :text, name: 'ニコニコ動画 URL', hide_on: %i[index new edit], format_using: -> { link_to(value, value, target: "_blank", rel: "noopener") }
  field :apple_music_url, as: :text, name: 'Apple Music URL', hide_on: %i[index new edit], format_using: -> { link_to(value, value, target: "_blank", rel: "noopener") }
  field :youtube_music_url, as: :text, name: 'YouTube Music URL', hide_on: %i[index new edit], format_using: -> { link_to(value, value, target: "_blank", rel: "noopener") }
  field :spotify_url, as: :text, name: 'Spotify URL', hide_on: %i[index new edit], format_using: -> { link_to(value, value, target: "_blank", rel: "noopener") }
  field :line_music_url, as: :text, name: 'LINE MUSIC URL', hide_on: %i[index new edit], format_using: -> { link_to(value, value, target: "_blank", rel: "noopener") }

  field :karaoke_delivery_models, as: :has_many, name: '配信機種'
  field :original_songs, as: :has_many, name: '原曲', searchable: true, attach_scope: -> { query.non_duplicated }

  field :song_with_dam_ouchikaraoke, as: :has_one, name: 'DAMおうちカラオケ', hide_on: [:index]
  field :song_with_joysound_utasuki, as: :has_one, name: 'JOYSOUNDうたスキ', hide_on: [:index]

  field :complex_name, as: :text, name: '複合名', hide_on: :all, as_label: true do |model|
    "[#{model.karaoke_type}] #{model.title}"
  end

  action ExportSongs
  action ExportMissingOriginalSongs
  action ImportSongsWithOriginalSongs
  action FetchDamSongs
  action UpdateDamDeliveryModels
  action FetchJoysoundSongs
  action FetchJoysoundMusicPostSong
  action RefreshJoysoundMusicPostSong
  action UpdateJoysoundMusicPostDeliveryDeadlineDates

  filter KaraokeTypeFilter
  filter MissingOriginalSongsFilter
end

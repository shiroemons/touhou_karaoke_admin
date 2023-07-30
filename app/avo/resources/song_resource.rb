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

  field :id, as: :id, hide_on: [:index]
  field :karaoke_type, as: :text, readonly: true, sortable: true
  field :song_number, as: :text, readonly: true, hide_on: [:index]
  field :display_artist, as: :belongs_to, readonly: true, sortable: true
  field :title, as: :text, readonly: true, sortable: true, link_to_resource: true
  field :title_reading, as: :text, readonly: true, hide_on: [:index]
  field :url, as: :text, readonly: true, format_using: -> { link_to(value, value, target: "_blank", rel: "noopener") }, hide_on: %i[index new edit]

  field :touhou?, as: :text, name: 'touhou', only_on: [:index], format_using: -> { value.present? ? '✅' : '' }, index_text_align: :center
  field :youtube_url, as: :text, only_on: [:index], format_using: -> { value.present? ? '✅' : '' }, index_text_align: :center
  field :nicovideo_url, as: :text, only_on: [:index], format_using: -> { value.present? ? '✅' : '' }, index_text_align: :center
  field :apple_music_url, as: :text, only_on: [:index], format_using: -> { value.present? ? '✅' : '' }, index_text_align: :center
  field :youtube_music_url, as: :text, only_on: [:index], format_using: -> { value.present? ? '✅' : '' }, index_text_align: :center
  field :spotify_url, as: :text, only_on: [:index], format_using: -> { value.present? ? '✅' : '' }, index_text_align: :center
  field :line_music_url, as: :text, only_on: [:index], format_using: -> { value.present? ? '✅' : '' }, index_text_align: :center

  field :youtube_url, as: :text, only_on: %i[new edit]
  field :nicovideo_url, as: :text, only_on: %i[new edit]
  field :apple_music_url, as: :text, only_on: %i[new edit]
  field :youtube_music_url, as: :text, only_on: %i[new edit]
  field :spotify_url, as: :text, only_on: %i[new edit]
  field :line_music_url, as: :text, only_on: %i[new edit]

  field :youtube_url, as: :text, hide_on: %i[index new edit], format_using: -> { link_to(value, value, target: "_blank", rel: "noopener") }
  field :nicovideo_url, as: :text, hide_on: %i[index new edit], format_using: -> { link_to(value, value, target: "_blank", rel: "noopener") }
  field :apple_music_url, as: :text, hide_on: %i[index new edit], format_using: -> { link_to(value, value, target: "_blank", rel: "noopener") }
  field :youtube_music_url, as: :text, hide_on: %i[index new edit], format_using: -> { link_to(value, value, target: "_blank", rel: "noopener") }
  field :spotify_url, as: :text, hide_on: %i[index new edit], format_using: -> { link_to(value, value, target: "_blank", rel: "noopener") }
  field :line_music_url, as: :text, hide_on: %i[index new edit], format_using: -> { link_to(value, value, target: "_blank", rel: "noopener") }

  field :karaoke_delivery_models, as: :has_many
  field :original_songs, as: :has_many, searchable: true, attach_scope: -> { query.non_duplicated }

  field :song_with_dam_ouchikaraoke, as: :has_one, hide_on: [:index]
  field :song_with_joysound_utasuki, as: :has_one, hide_on: [:index]

  field :complex_name, as: :text, hide_on: :all, as_label: true do |model|
    "[#{model.karaoke_type}] #{model.title}"
  end

  action ExportMissingOriginalSongs
  action ImportSongsWithOriginalSongs
  action FetchDamSongs
  action FetchJoysoundSongs
  action FetchJoysoundMusicPostSong
  action RefreshJoysoundMusicPostSong

  filter KaraokeTypeFilter
  filter MissingOriginalSongsFilter
end

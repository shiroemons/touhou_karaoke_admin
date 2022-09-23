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
  field :song_number, as: :text, readonly: true, sortable: true
  field :display_artist, as: :belongs_to, readonly: true, sortable: true
  field :title, as: :text, readonly: true, sortable: true, link_to_resource: true
  field :title_reading, as: :text, readonly: true, sortable: true
  field :url, as: :text, readonly: true, format_using: ->(url) { link_to(url, url, target: "_blank", rel: "noopener") }

  field :youtube_url, as: :text, hide_on: [:index], format_using: ->(url) { link_to(url, url, target: "_blank", rel: "noopener") }
  field :nicovideo_url, as: :text, hide_on: [:index], format_using: ->(url) { link_to(url, url, target: "_blank", rel: "noopener") }
  field :apple_music_url, as: :text, hide_on: [:index], format_using: ->(url) { link_to(url, url, target: "_blank", rel: "noopener") }
  field :youtube_music_url, as: :text, hide_on: [:index], format_using: ->(url) { link_to(url, url, target: "_blank", rel: "noopener") }
  field :spotify_url, as: :text, hide_on: [:index], format_using: ->(url) { link_to(url, url, target: "_blank", rel: "noopener") }
  field :line_music_url, as: :text, hide_on: [:index], format_using: ->(url) { link_to(url, url, target: "_blank", rel: "noopener") }

  field :karaoke_delivery_models, as: :has_many
  field :original_songs, as: :has_many, searchable: true, attach_scope: -> { query.non_duplicated }

  field :song_with_dam_ouchikaraoke, as: :has_one, hide_on: [:index]
  field :song_with_joysound_utasuki, as: :has_one, hide_on: [:index]

  action FetchDamSongs
  action FetchJoysoundSongs
  action FetchJoysoundMusicPostSong
  action RefreshJoysoundMusicPostSong

  filter KaraokeTypeFilter
  filter MissingOriginalSongsFilter
end

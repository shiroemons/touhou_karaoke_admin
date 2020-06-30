require "administrate/base_dashboard"

class SongDashboard < Administrate::BaseDashboard
  # ATTRIBUTE_TYPES
  # a hash that describes the type of each of the model's fields.
  #
  # Each different type represents an Administrate::Field object,
  # which determines how the attribute is displayed
  # on pages throughout the dashboard.
  ATTRIBUTE_TYPES = {
    song_with_dam_ouchikaraoke: Field::HasOne,
    song_with_joysound_utasuki: Field::HasOne,
    songs_karaoke_delivery_models: Field::HasMany,
    karaoke_delivery_models: Field::HasMany,
    songs_original_songs: Field::HasMany,
    original_songs: Field::HasMany,
    display_artist: Field::BelongsTo,
    id: Field::String.with_options(searchable: false),
    title: Field::String,
    title_reading: Field::String,
    karaoke_type: Field::String,
    song_number: Field::String,
    url: Field::String,
    created_at: Field::DateTime,
    updated_at: Field::DateTime,
  }.freeze

  # COLLECTION_ATTRIBUTES
  # an array of attributes that will be displayed on the model's index page.
  #
  # By default, it's limited to four items to reduce clutter on index pages.
  # Feel free to add, remove, or rearrange items.
  COLLECTION_ATTRIBUTES = %i[
  song_with_dam_ouchikaraoke
  song_with_joysound_utasuki
  songs_karaoke_delivery_models
  karaoke_delivery_models
  ].freeze

  # SHOW_PAGE_ATTRIBUTES
  # an array of attributes that will be displayed on the model's show page.
  SHOW_PAGE_ATTRIBUTES = %i[
  song_with_dam_ouchikaraoke
  song_with_joysound_utasuki
  songs_karaoke_delivery_models
  karaoke_delivery_models
  songs_original_songs
  original_songs
  display_artist
  id
  title
  title_reading
  karaoke_type
  song_number
  url
  created_at
  updated_at
  ].freeze

  # FORM_ATTRIBUTES
  # an array of attributes that will be displayed
  # on the model's form (`new` and `edit`) pages.
  FORM_ATTRIBUTES = %i[
  song_with_dam_ouchikaraoke
  song_with_joysound_utasuki
  songs_karaoke_delivery_models
  karaoke_delivery_models
  songs_original_songs
  original_songs
  display_artist
  title
  title_reading
  karaoke_type
  song_number
  url
  ].freeze

  # COLLECTION_FILTERS
  # a hash that defines filters that can be used while searching via the search
  # field of the dashboard.
  #
  # For example to add an option to search for open resources by typing "open:"
  # in the search field:
  #
  #   COLLECTION_FILTERS = {
  #     open: ->(resources) { resources.where(open: true) }
  #   }.freeze
  COLLECTION_FILTERS = {}.freeze

  # Overwrite this method to customize how songs are displayed
  # across all pages of the admin dashboard.
  #
  # def display_resource(song)
  #   "Song ##{song.id}"
  # end
end

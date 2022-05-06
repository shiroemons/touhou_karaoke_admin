require "administrate/base_dashboard"

class SongDashboard < Administrate::BaseDashboard
  # ATTRIBUTE_TYPES
  # a hash that describes the type of each of the model's fields.
  #
  # Each different type represents an Administrate::Field object,
  # which determines how the attribute is displayed
  # on pages throughout the dashboard.
  ATTRIBUTE_TYPES = {
    id: Field::String.with_options(searchable: false),
    display_artist: Field::BelongsTo.with_options(
      searchable: true,
      searchable_field: 'name',
    ),
    title: Field::String,
    title_reading: Field::String,
    karaoke_type: Field::String,
    song_number: Field::String,
    url: Field::String,
    youtube_url: Field::String,
    nicovideo_url: Field::String,
    apple_music_url: Field::String,
    original_songs: Field::HasMany.with_options(
      searchable: true,
      searchable_field: 'title',
    ),
    karaoke_delivery_models: Field::HasMany.with_options(
      searchable: true,
      searchable_field: 'name',
    ),
    song_with_dam_ouchikaraoke: Field::HasOne,
    song_with_joysound_utasuki: Field::HasOne,
    songs_original_songs: Field::HasMany,
    songs_karaoke_delivery_models: Field::HasMany,
    created_at: Field::DateTime.with_options(format: "%Y/%m/%d %T"),
    updated_at: Field::DateTime.with_options(format: "%Y/%m/%d %T"),
  }.freeze

  # COLLECTION_ATTRIBUTES
  # an array of attributes that will be displayed on the model's index page.
  #
  # By default, it's limited to four items to reduce clutter on index pages.
  # Feel free to add, remove, or rearrange items.
  COLLECTION_ATTRIBUTES = %i[
    title
  display_artist
  karaoke_type
  song_number
  original_songs
  ].freeze

  # SHOW_PAGE_ATTRIBUTES
  # an array of attributes that will be displayed on the model's show page.
  SHOW_PAGE_ATTRIBUTES = %i[
    id
  title
  title_reading
  display_artist
  karaoke_type
  song_number
  url
  youtube_url
  nicovideo_url
  apple_music_url
  original_songs
  karaoke_delivery_models
  song_with_joysound_utasuki
  song_with_dam_ouchikaraoke
  created_at
  updated_at
  ].freeze

  # FORM_ATTRIBUTES
  # an array of attributes that will be displayed
  # on the model's form (`new` and `edit`) pages.
  FORM_ATTRIBUTES = %i[
    youtube_url
  nicovideo_url
  apple_music_url
  original_songs
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
  def display_resource(song)
    song.title
  end
end

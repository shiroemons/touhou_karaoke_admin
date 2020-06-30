require "administrate/base_dashboard"

class OriginalSongDashboard < Administrate::BaseDashboard
  # ATTRIBUTE_TYPES
  # a hash that describes the type of each of the model's fields.
  #
  # Each different type represents an Administrate::Field object,
  # which determines how the attribute is displayed
  # on pages throughout the dashboard.
  ATTRIBUTE_TYPES = {
    songs_original_songs: Field::HasMany,
    songs: Field::HasMany,
    original: Field::BelongsTo,
    code: Field::String,
    original_code: Field::String,
    title: Field::String,
    composer: Field::String,
    track_number: Field::Number,
    is_duplicate: Field::Boolean,
    created_at: Field::DateTime,
    updated_at: Field::DateTime,
  }.freeze

  # COLLECTION_ATTRIBUTES
  # an array of attributes that will be displayed on the model's index page.
  #
  # By default, it's limited to four items to reduce clutter on index pages.
  # Feel free to add, remove, or rearrange items.
  COLLECTION_ATTRIBUTES = %i[
  songs_original_songs
  songs
  original
  code
  ].freeze

  # SHOW_PAGE_ATTRIBUTES
  # an array of attributes that will be displayed on the model's show page.
  SHOW_PAGE_ATTRIBUTES = %i[
  songs_original_songs
  songs
  original
  code
  original_code
  title
  composer
  track_number
  is_duplicate
  created_at
  updated_at
  ].freeze

  # FORM_ATTRIBUTES
  # an array of attributes that will be displayed
  # on the model's form (`new` and `edit`) pages.
  FORM_ATTRIBUTES = %i[
  songs_original_songs
  songs
  original
  code
  original_code
  title
  composer
  track_number
  is_duplicate
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

  # Overwrite this method to customize how original songs are displayed
  # across all pages of the admin dashboard.
  #
  # def display_resource(original_song)
  #   "OriginalSong ##{original_song.id}"
  # end
end

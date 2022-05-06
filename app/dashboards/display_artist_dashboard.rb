require "administrate/base_dashboard"

class DisplayArtistDashboard < Administrate::BaseDashboard
  # ATTRIBUTE_TYPES
  # a hash that describes the type of each of the model's fields.
  #
  # Each different type represents an Administrate::Field object,
  # which determines how the attribute is displayed
  # on pages throughout the dashboard.
  ATTRIBUTE_TYPES = {
    id: Field::String.with_options(searchable: false),
    name: Field::String,
    name_reading: Field::String,
    karaoke_type: Field::String,
    url: Field::String,
    songs: Field::HasMany,
    dam_songs: Field::HasMany,
    circles: Field::HasMany,
    display_artists_circles: Field::HasMany,
    created_at: Field::DateTime.with_options(format: "%Y/%m/%d %T"),
    updated_at: Field::DateTime.with_options(format: "%Y/%m/%d %T")
  }.freeze

  # COLLECTION_ATTRIBUTES
  # an array of attributes that will be displayed on the model's index page.
  #
  # By default, it's limited to four items to reduce clutter on index pages.
  # Feel free to add, remove, or rearrange items.
  COLLECTION_ATTRIBUTES = %i[
    name
  name_reading
  karaoke_type
  circles
  songs
  ].freeze

  # SHOW_PAGE_ATTRIBUTES
  # an array of attributes that will be displayed on the model's show page.
  SHOW_PAGE_ATTRIBUTES = %i[
    id
  name
  name_reading
  karaoke_type
  url
  circles
  songs
  created_at
  updated_at
  ].freeze

  # FORM_ATTRIBUTES
  # an array of attributes that will be displayed
  # on the model's form (`new` and `edit`) pages.
  FORM_ATTRIBUTES = %i[
    circles
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

  # Overwrite this method to customize how display artists are displayed
  # across all pages of the admin dashboard.
  #
  def display_resource(display_artist)
    display_artist.name
  end
end

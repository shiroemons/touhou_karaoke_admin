class DisplayArtistResource < Avo::BaseResource
  self.title = :name
  self.translation_key = 'avo.resource_translations.display_artist'
  self.includes = []
  self.search_query = lambda {
    scope.ransack(name_cont: params[:q], m: "or").result(distinct: false)
  }

  field :id, as: :id, hide_on: [:index]
  field :karaoke_type, as: :text, readonly: true, sortable: true
  field :name, as: :text, readonly: true, sortable: true
  field :name_reading, as: :text, readonly: true, sortable: true
  field :url, as: :text, readonly: true

  field :circles, as: :has_many
  field :songs, as: :has_many
  field :dam_songs, as: :has_many

  field :complex_name, as: :text, hide_on: :all, as_label: true do |model|
    "[#{model.karaoke_type}] #{model.name}"
  end

  action FetchDamArtist
  action FetchJoysoundArtist
  action FetchJoysoundMusicPostArtist

  filter KaraokeTypeFilter
end

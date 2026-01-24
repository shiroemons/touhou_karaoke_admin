class DisplayArtistResource < Avo::BaseResource
  self.title = :name
  self.translation_key = 'avo.resource_translations.display_artist'
  self.includes = [:circles]
  self.search_query = lambda {
    scope.ransack(name_cont: params[:q], m: "or").result(distinct: false)
  }
  self.resolve_query_scope = lambda { |model_class:|
    model_class.order(created_at: :desc)
  }

  field :id, as: :id, hide_on: [:index]
  field :circle, as: :text, only_on: [:index], index_text_align: :center do |model|
    model.circles.present? ? '✅' : ''
  end
  field :karaoke_type, as: :text, readonly: true, sortable: true
  field :name, as: :text, readonly: true, sortable: true
  field :name_reading, as: :text, sortable: true
  field :url, as: :text, format_using: -> { link_to(value, value, target: "_blank", rel: "noopener") }

  field :circles, as: :has_many, searchable: true
  field :songs, as: :has_many
  field :dam_songs, as: :has_many

  field :complex_name, as: :text, hide_on: :all, as_label: true do |model|
    "[#{model.karaoke_type}] #{model.name}"
  end

  action FetchDamArtist
  action FetchJoysoundArtist
  action FetchJoysoundMusicPostArtist
  action ValidateDisplayArtistUrls
  action CleanupInvalidDisplayArtists
  action CleanupOrphanDisplayArtists

  filter KaraokeTypeFilter
end

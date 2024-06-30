class DamSongResource < Avo::BaseResource
  self.title = :title
  self.translation_key = 'avo.resource_translations.dam_song'
  self.includes = [:display_artist]
  self.search_query = lambda {
    scope.ransack(display_artist_name_cont: params[:q], title_cont: params[:q], m: "or").result(distinct: false)
  }
  self.resolve_query_scope = lambda { |model_class:|
    model_class.order(created_at: :desc)
  }

  field :id, as: :id, hide_on: [:index]
  field :display_artist, as: :belongs_to
  field :title, as: :text, readonly: true, sortable: true
  field :url, as: :text, readonly: true, format_using: -> { link_to(value, value, target: "_blank", rel: "noopener") }

  field :complex_name, as: :text, hide_on: :all, as_label: true do |model|
    "[#{model.display_artist.name}] #{model.title}"
  end

  # action FetchDamSong
  action FetchDamTouhouSongs
  action FetchDamSong
end

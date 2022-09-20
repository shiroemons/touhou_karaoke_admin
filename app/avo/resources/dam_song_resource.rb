class DamSongResource < Avo::BaseResource
  self.title = :title
  self.translation_key = 'avo.resource_translations.dam_song'
  self.includes = [:display_artist]
  self.search_query = lambda {
    scope.ransack(display_artist_name_cont: params[:q], title_cont: params[:q], m: "or").result(distinct: false)
  }

  field :id, as: :id, hide_on: [:index]
  field :display_artist, as: :belongs_to
  field :title, as: :text, readonly: true, sortable: true
  field :url, as: :text, readonly: true

  field :complex_name, as: :text, hide_on: :all, as_label: true do |model|
    "[#{model.display_artist.name}] #{model.title}"
  end

  action FetchDamSong
end

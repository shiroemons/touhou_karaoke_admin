class JoysoundMusicPostResource < Avo::BaseResource
  self.title = :title
  self.translation_key = 'avo.resource_translations.joysound_music_post'
  self.includes = []
  self.search_query = lambda {
    scope.ransack(artist_cont: params[:q], title_cont: params[:q], m: "or").result(distinct: false)
  }

  field :id, as: :id, hide_on: [:index]
  field :title, as: :text, readonly: true, sortable: true
  field :artist, as: :text, readonly: true, sortable: true
  field :producer, as: :text, readonly: true, sortable: true
  field :delivery_deadline_on, as: :date, readonly: true, sortable: true
  field :url, as: :text, readonly: true, sortable: true

  field :complex_name, as: :text, hide_on: :all, as_label: true do |model|
    "[#{model.artist}] #{model.title}"
  end

  action FetchMusicPost
  action FetchMusicPostSongJoysoundUrl
end

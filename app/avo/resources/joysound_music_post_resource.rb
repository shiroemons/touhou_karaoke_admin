class JoysoundMusicPostResource < Avo::BaseResource
  self.title = :title
  self.translation_key = 'avo.resource_translations.joysound_music_post'
  self.includes = []
  self.search_query = lambda {
    scope.ransack(artist_cont: params[:q], title_cont: params[:q], m: "or").result(distinct: false)
  }
  self.resolve_query_scope = lambda { |model_class:|
    model_class.order(created_at: :desc)
  }

  field :id, as: :id, hide_on: [:index]
  field :title, as: :text, readonly: true, sortable: true
  field :artist, as: :text, readonly: true, sortable: true
  field :producer, as: :text, readonly: true, sortable: true
  field :delivery_deadline_on, as: :date, readonly: true, sortable: true
  field :url, as: :text, readonly: true, hide_on: %i[index show]
  field :url, as: :text, hide_on: [:edit], sortable: true, format_using: -> { link_to(value, value, target: "_blank", rel: "noopener") }
  field :joysound_url, as: :text, hide_on: %i[index show]
  field :joysound_url, as: :text, hide_on: [:edit], sortable: true, format_using: -> { link_to(value, value, target: "_blank", rel: "noopener") }

  field :complex_name, as: :text, hide_on: :all, as_label: true do |model|
    "[#{model.artist}] #{model.title}"
  end

  action FetchMusicPost
  action FetchMusicPostSongJoysoundUrl
end

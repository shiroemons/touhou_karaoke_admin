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

  field :id, as: :id, name: 'ID', hide_on: [:index]
  field :title, as: :text, name: 'タイトル', readonly: true, sortable: true
  field :artist, as: :text, name: 'アーティスト', readonly: true, sortable: true
  field :producer, as: :text, name: 'プロデューサー', readonly: true, sortable: true
  field :delivery_deadline_on, as: :date, name: '配信期限', readonly: true, sortable: true
  field :url, as: :text, name: 'URL', readonly: true, hide_on: %i[index show]
  field :url, as: :text, name: 'URL', hide_on: [:edit], sortable: true, format_using: -> { link_to(value, value, target: "_blank", rel: "noopener") }
  field :joysound_url, as: :text, name: 'JOYSOUND URL', hide_on: %i[index show]
  field :joysound_url, as: :text, name: 'JOYSOUND URL', hide_on: [:edit], sortable: true, format_using: -> { link_to(value, value, target: "_blank", rel: "noopener") }

  field :complex_name, as: :text, name: '複合名', hide_on: :all, as_label: true do |model|
    "[#{model.artist}] #{model.title}"
  end

  action FetchMusicPost
  action FetchMusicPostSongJoysoundUrl
  action CleanupExpiredJoysoundMusicPosts
  action PerformFullJoysoundMusicPostMaintenance
end

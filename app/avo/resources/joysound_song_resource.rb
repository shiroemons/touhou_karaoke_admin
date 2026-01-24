class JoysoundSongResource < Avo::BaseResource
  self.title = :display_title
  self.translation_key = 'avo.resource_translations.joysound_song'
  self.includes = []
  self.search_query = lambda {
    scope.ransack(display_title_cont: params[:q], m: "or").result(distinct: false)
  }
  self.resolve_query_scope = lambda { |model_class:|
    model_class.order(created_at: :desc)
  }

  field :id, as: :id, name: 'ID', hide_on: [:index]
  field :display_title, as: :text, name: '表示タイトル', readonly: true, sortable: true
  field :url, as: :text, name: 'URL', readonly: true, format_using: -> { link_to(value, value, target: "_blank", rel: "noopener") }
  field :smartphone_service_enabled, as: :boolean, name: 'スマートフォンサービス', readonly: true
  field :home_karaoke_enabled, as: :boolean, name: '家庭用カラオケ', readonly: true

  action FetchJoysoundTouhouSongs
  action FetchJoysoundDetail
end

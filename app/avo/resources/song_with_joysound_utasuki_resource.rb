class SongWithJoysoundUtasukiResource < Avo::BaseResource
  self.title = :url
  self.translation_key = 'avo.resource_translations.song_with_joysound_utasuki'
  self.includes = []
  self.visible_on_sidebar = false
  # self.search_query = -> do
  #   scope.ransack(id_eq: params[:q], m: "or").result(distinct: false)
  # end

  field :id, as: :id, hide_on: [:index]
  field :song, as: :belongs_to
  field :delivery_deadline_date, as: :date, readonly: true, sortable: true
  field :url, as: :text, readonly: true, format_using: ->(url) { link_to(url, url, target: "_blank", rel: "noopener") }
end

class CircleResource < Avo::BaseResource
  self.title = :name
  self.translation_key = 'avo.resource_translations.circle'
  self.includes = [:display_artists]

  self.search_query = lambda {
    scope.ransack(name_cont: params[:q], m: "or").result(distinct: false)
  }

  field :id, as: :id, hide_on: [:index]
  field :name, as: :text, required: true, sortable: true, link_to_resource: true
  field :display_artists_count, as: :number, only_on: [:index], index_text_align: :right
  field :songs_count, as: :number, only_on: [:index], index_text_align: :right

  field :display_artists, as: :has_many
  field :songs, as: :has_many
end

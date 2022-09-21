class CircleResource < Avo::BaseResource
  self.title = :name
  self.translation_key = 'avo.resource_translations.circle'
  self.includes = [:display_artists]

  self.search_query = lambda {
    scope.ransack(name_cont: params[:q], m: "or").result(distinct: false)
  }

  field :id, as: :id, hide_on: [:index]
  field :name, as: :text, required: true, sortable: true
  field :display_artists, as: :has_many
end

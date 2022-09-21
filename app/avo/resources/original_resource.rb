class OriginalResource < Avo::BaseResource
  self.title = :title
  self.translation_key = 'avo.resource_translations.original'
  self.search_query = lambda {
    scope.ransack(title_cont: params[:q], m: "or").result(distinct: false)
  }

  field :id, as: :id, hide_on: [:index]
  field :title, as: :text, readonly: true, sortable: true
  field :short_title, as: :text, readonly: true, sortable: true
  field :original_type, as: :badge, readonly: true
  field :series_order, as: :number, readonly: true, index_text_align: :right

  field :original_songs, as: :has_many
end

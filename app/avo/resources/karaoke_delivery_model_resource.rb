class KaraokeDeliveryModelResource < Avo::BaseResource
  self.title = :name
  self.translation_key = 'avo.resource_translations.karaoke_delivery_model'
  self.includes = []
  self.search_query = lambda {
    scope.ransack(name_cont: params[:q], m: "or").result(distinct: false)
  }

  field :id, as: :id, hide_on: [:index]
  field :name, as: :text, readonly: true, sortable: true
  field :karaoke_type, as: :text, readonly: true, sortable: true
  field :order, as: :number, readonly: true, index_text_align: :right
end

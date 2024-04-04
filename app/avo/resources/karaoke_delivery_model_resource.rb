class KaraokeDeliveryModelResource < Avo::BaseResource
  self.title = :name
  self.translation_key = 'avo.resource_translations.karaoke_delivery_model'
  self.includes = []
  self.search_query = lambda {
    scope.ransack(name_cont: params[:q], m: "or").result(distinct: false)
  }

  field :id, as: :id, hide_on: [:index]
  field :name, as: :text, required: true, sortable: true
  field :karaoke_type, required: true, as: :select, options: { 'DAM': 'DAM', 'JOYSOUND': 'JOYSOUND' }, display_with_value: true, placeholder: 'カラオケメーカーを選択してください', sortable: true
  field :order, as: :number, index_text_align: :right
end

class KaraokeDeliveryModelResource < Avo::BaseResource
  self.title = :name
  self.translation_key = 'avo.resource_translations.karaoke_delivery_model'
  self.includes = []
  self.search_query = lambda {
    scope.ransack(name_cont: params[:q], m: "or").result(distinct: false)
  }
  self.resolve_query_scope = lambda { |model_class:|
    model_class.order(order: :asc)
  }
  self.ordering = {
    display_inline: true,
    visible_on: :index,
    actions: {
      higher: -> { record.move_higher },
      lower: -> { record.move_lower },
      to_top: -> { record.move_to_top },
      to_bottom: -> { record.move_to_bottom }
    }
  }

  field :id, as: :id, name: 'ID', hide_on: [:index]
  field :name, as: :text, name: '機種名', required: true, sortable: true
  field :karaoke_type, name: 'カラオケ種別', required: true, as: :select, options: { DAM: 'DAM', JOYSOUND: 'JOYSOUND' }, display_with_value: true, placeholder: 'カラオケメーカーを選択してください', sortable: true
  field :order, as: :number, name: '表示順', index_text_align: :right
end

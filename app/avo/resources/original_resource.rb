class OriginalResource < Avo::BaseResource
  self.title = :title
  self.translation_key = 'avo.resource_translations.original'
  self.search_query = lambda {
    scope.ransack(title_cont: params[:q], m: "or").result(distinct: false)
  }

  field :id, as: :id, name: 'ID', hide_on: [:index]
  field :title, as: :text, name: '作品名', readonly: true, sortable: true
  field :short_title, as: :text, name: '短縮タイトル', readonly: true, sortable: true
  field :original_type, as: :badge, name: '種別', readonly: true
  field :series_order, as: :number, name: 'シリーズ順', readonly: true, index_text_align: :right

  field :original_songs, as: :has_many, name: '原曲'
end

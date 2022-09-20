class OriginalSongResource < Avo::BaseResource
  self.title = :title
  self.translation_key = 'avo.resource_translations.original_song'
  self.includes = [:original]
  self.search_query = lambda {
    scope.ransack(title_cont: params[:q], m: "or").result(distinct: false)
  }

  field :id, as: :id, hide_on: [:index]
  field :original, as: :belongs_to
  field :title, as: :text, readonly: true, sortable: true
  field :composer, as: :text, readonly: true, sortable: true
  field :track_number, as: :number, readonly: true, index_text_align: :right, sortable: true
  field :is_duplicate, as: :boolean, readonly: true

  field :songs, as: :has_many
end

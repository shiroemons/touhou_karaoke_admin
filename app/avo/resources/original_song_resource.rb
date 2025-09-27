class OriginalSongResource < Avo::BaseResource
  self.title = :title
  self.translation_key = 'avo.resource_translations.original_song'
  self.includes = [:original]
  self.search_query = lambda {
    scope.ransack(title_cont: params[:q], m: "or").result(distinct: false)
  }
  self.resolve_query_scope = lambda { |model_class:|
    model_class.order(code: :asc)
  }

  field :id, as: :id, hide_on: [:index]
  field :original, as: :belongs_to
  field :title, as: :text, readonly: true, sortable: true
  field :composer, as: :text, readonly: true, sortable: true
  field :track_number, as: :number, readonly: true, index_text_align: :right, sortable: true
  field :is_duplicate, as: :boolean, readonly: true

  field :complex_name, as: :text, hide_on: :all, as_label: true do |model|
    "[#{model.original_short_title}] #{model.title}"
  end

  field :songs, as: :has_many
end

class SongWithDamOuchikaraokeResource < Avo::BaseResource
  self.title = :url
  self.translation_key = 'avo.resource_translations.song_with_dam_ouchikaraoke'
  self.includes = []
  self.visible_on_sidebar = false
  # self.search_query = -> do
  #   scope.ransack(id_eq: params[:q], m: "or").result(distinct: false)
  # end

  field :id, as: :id, hide_on: [:index]
  field :song, as: :belongs_to
  field :url, as: :text, readonly: true
end

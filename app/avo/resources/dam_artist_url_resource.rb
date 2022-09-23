class DamArtistUrlResource < Avo::BaseResource
  self.title = :url
  self.translation_key = 'avo.resource_translations.dam_artist_url'
  self.includes = []
  self.search_query = lambda {
    scope.ransack(url_cont: params[:q], m: "or").result(distinct: false)
  }

  field :id, as: :id, hide_on: [:index]
  field :url, as: :text
end
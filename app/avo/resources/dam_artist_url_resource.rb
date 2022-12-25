class DamArtistUrlResource < Avo::BaseResource
  self.title = :url
  self.translation_key = 'avo.resource_translations.dam_artist_url'
  self.includes = []
  self.search_query = lambda {
    scope.ransack(url_cont: params[:q], m: "or").result(distinct: false)
  }

  field :id, as: :id, hide_on: [:index]
  field :url, as: :text, hide_on: [:index, :show]
  field :url, as: :text, format_using: ->(url) { link_to(url, url, target: "_blank", rel: "noopener") }, hide_on: [:new, :edit]
end

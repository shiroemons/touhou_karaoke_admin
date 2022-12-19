class FetchDamArtist < Avo::BaseAction
  self.name = "Fetch dam artist"
  self.standalone = true

  def handle(_args)
    DamArtistUrl.fetch_dam_artist
    succeed 'Done!'
    reload
  end
end

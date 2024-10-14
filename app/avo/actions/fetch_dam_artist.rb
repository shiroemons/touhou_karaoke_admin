class FetchDamArtist < Avo::BaseAction
  self.name = "DAMのアーティストを取得"
  self.standalone = true

  def handle(_args)
    DamArtistUrl.fetch_dam_artist
    succeed 'Done!'
    reload
  end
end

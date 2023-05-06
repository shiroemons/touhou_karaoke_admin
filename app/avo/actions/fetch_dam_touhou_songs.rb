class FetchDamTouhouSongs < Avo::BaseAction
  self.name = "Fetch dam touhou songs"
  self.standalone = true

  def handle(_args)
    DamSong.fetch_dam_touhou_songs
    succeed 'Done!'
    reload
  end
end

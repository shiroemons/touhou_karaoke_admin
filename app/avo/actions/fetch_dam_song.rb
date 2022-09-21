class FetchDamSong < Avo::BaseAction
  self.name = "Fetch dam song"
  self.standalone = true

  def handle(_args)
    DamSong.fetch_dam_songs
  end
end

class FetchDamSongs < Avo::BaseAction
  self.name = "Fetch dam songs"
  self.standalone = true

  def handle(_args)
    Song.fetch_dam_songs
  end
end

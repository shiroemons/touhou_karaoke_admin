class FetchDamSongs < Avo::BaseAction
  self.name = "Fetch dam songs"
  self.standalone = true

  def handle(_args)
    Song.fetch_dam_songs
    succeed 'Done!'
    reload
  end
end

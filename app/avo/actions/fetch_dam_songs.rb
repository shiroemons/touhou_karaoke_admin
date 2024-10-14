class FetchDamSongs < Avo::BaseAction
  self.name = "DAMの楽曲を取得"
  self.standalone = true

  def handle(_args)
    Song.fetch_dam_songs
    succeed 'Done!'
    reload
  end
end

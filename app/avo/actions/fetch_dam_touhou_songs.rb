class FetchDamTouhouSongs < Avo::BaseAction
  self.name = "DAMの東方楽曲を取得"
  self.standalone = true

  def handle(_args)
    DamSong.fetch_dam_touhou_songs
    succeed 'Done!'
    reload
  end
end

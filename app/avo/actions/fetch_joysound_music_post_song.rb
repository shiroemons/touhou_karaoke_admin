class FetchJoysoundMusicPostSong < Avo::BaseAction
  self.name = "JOYSOUNDミュージックポストの楽曲を取得"
  self.standalone = true

  def handle(_args)
    Song.fetch_joysound_music_post_song
    succeed 'Done!'
    reload
  end
end

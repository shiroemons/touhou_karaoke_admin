class RefreshJoysoundMusicPostSong < Avo::BaseAction
  self.name = "JOYSOUNDミュージックポスト楽曲の更新"
  self.standalone = true

  def handle(_args)
    Song.refresh_joysound_music_post_song
    succeed 'Done!'
    reload
  end
end

class FetchMusicPostSongJoysoundUrl < Avo::BaseAction
  self.name = "JOYSOUNDミュージックポストの楽曲URLを取得"
  self.standalone = true

  def handle(_args)
    JoysoundMusicPost.fetch_music_post_song_joysound_url
    succeed 'Done!'
    reload
  end
end

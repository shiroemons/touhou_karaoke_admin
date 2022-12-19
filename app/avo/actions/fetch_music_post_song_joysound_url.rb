class FetchMusicPostSongJoysoundUrl < Avo::BaseAction
  self.name = "Fetch music post song joysound url"
  self.standalone = true

  def handle(_args)
    JoysoundMusicPost.fetch_music_post_song_joysound_url
    succeed 'Done!'
    reload
  end
end

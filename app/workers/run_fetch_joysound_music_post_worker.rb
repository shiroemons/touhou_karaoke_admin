class RunFetchJoysoundMusicPostWorker
  include Sidekiq::Worker
  sidekiq_options queue: :fetch_joysound_music_post
  Sidekiq::Queue['fetch_joysound_music_post'].limit = 1

  def perform(*args)
    JoysoundMusicPost.fetch_music_post
    DisplayArtist.fetch_joysound_music_post_artist
    JoysoundMusicPost.fetch_music_post_song_joysound_url
    Song.fetch_joysound_music_post_song
    Song.refresh_joysound_music_post_song
  end
end

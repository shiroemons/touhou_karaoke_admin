class RunFetchDamSongWorker
  include Sidekiq::Worker
  sidekiq_options queue: :fetch_dam_song
  Sidekiq::Queue['fetch_dam_song'].limit = 1

  def perform(*_args)
    DamArtistUrl.fetch_dam_artist
    DamSong.fetch_dam_songs
    Song.fetch_dam_songs
  end
end

require 'csv'

karaoke_songs = CSV.table('tmp/karaoke_songs.tsv', col_sep: "\t", converters: nil, liberal_parsing: true)
karaoke_songs.each do |karaoke_song|
  karaoke_type = karaoke_song[:karaoke_type]
  url = karaoke_song[:url]
  original_songs = karaoke_song[:original_songs]
  song = Song.find_by(karaoke_type:, url:)
  next unless song && original_songs

  original_song_list = OriginalSong.where(title: original_songs.split('/'), is_duplicate: false)
  song.original_songs = original_song_list
  song.youtube_url = karaoke_song[:youtube_url] if karaoke_song[:youtube_url]
  song.nicovideo_url = karaoke_song[:nicovideo_url] if karaoke_song[:nicovideo_url]
  song.apple_music_url = karaoke_song[:apple_music_url] if karaoke_song[:apple_music_url]
  song.save!
end

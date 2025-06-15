require 'csv'

target_songs = Song.spotify.where(apple_music_url: "")
total_count = target_songs.size

touhou_music_songs = CSV.table('tmp/touhou_music.tsv', col_sep: "\t", converters: nil, liberal_parsing: true)

target_songs.each.with_index(1) do |song, i|
  print "\r#{i}/#{total_count}: Progress: #{(i * 100.0 / total_count).round(1)}%"

  touhou_music_song = touhou_music_songs.find { it[:spotify_track_url] == song.spotify_url }
  next if touhou_music_song.blank?

  song.update(
    apple_music_url: touhou_music_song[:apple_music_track_url].to_s,
    youtube_music_url: touhou_music_song[:youtube_music_track_url].to_s,
    line_music_url: touhou_music_song[:line_music_track_url].to_s
  )
end

require 'csv'

karaoke_songs = CSV.table('tmp/karaoke_songs.tsv', col_sep: "\t", converters: nil, liberal_parsing: true)

song_total = Song.count
total_count = karaoke_songs.size

karaoke_types = karaoke_songs.pluck(:karaoke_type).uniq
urls = karaoke_songs.pluck(:url).uniq
songs_by_key = Song.where(karaoke_type: karaoke_types, url: urls)
                   .index_by { |song| [song.karaoke_type, song.url] }

original_song_titles_pool = karaoke_songs.flat_map { |row| row[:original_songs].to_s.split('/') }.uniq
original_songs_by_title = OriginalSong.where(title: original_song_titles_pool, is_duplicate: false).group_by(&:title)

karaoke_songs.each.with_index(1) do |karaoke_song, i|
  print "\rSongTotal:#{song_total}\t#{i}/#{total_count}: Progress: #{(i * 100.0 / total_count).round(1)}%"

  karaoke_type = karaoke_song[:karaoke_type]
  url = karaoke_song[:url]
  original_songs = karaoke_song[:original_songs]
  song = songs_by_key[[karaoke_type, url]]
  next unless song && original_songs

  original_song_list = original_songs.split('/').flat_map { |title| original_songs_by_title[title] || [] }.uniq
  song.original_songs = original_song_list
  song.youtube_url = karaoke_song[:youtube_url] if karaoke_song[:youtube_url]
  song.nicovideo_url = karaoke_song[:nicovideo_url] if karaoke_song[:nicovideo_url]
  song.apple_music_url = karaoke_song[:apple_music_url] if karaoke_song[:apple_music_url]
  song.youtube_music_url = karaoke_song[:youtube_music_url] if karaoke_song[:youtube_music_url]
  song.spotify_url = karaoke_song[:spotify_url] if karaoke_song[:spotify_url]
  song.line_music_url = karaoke_song[:line_music_url] if karaoke_song[:line_music_url]
  song.save!
end

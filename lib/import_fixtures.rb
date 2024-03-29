require 'csv'

CSV.table('db/fixtures/joysound_display_artist_with_circle.tsv', col_sep: "\t", converters: nil).each do |da|
  karaoke_type = da[:karaoke_type]
  display_artist_name = da[:display_artist]
  circle = da[:circle]
  display_artist = DisplayArtist.find_by(karaoke_type:, name: display_artist_name)
  if display_artist && circle.present?
    @circle = Circle.find_or_create_by(name: circle) if circle != @circle&.name
    display_artist.circles = [@circle] if @circle
  end
end

CSV.table('db/fixtures/joysound_musicpost_display_artist_with_circle.tsv', col_sep: "\t", converters: nil).each do |da|
  karaoke_type = da[:karaoke_type]
  display_artist_name = da[:display_artist]
  circle = da[:circle]
  display_artist = DisplayArtist.find_by(karaoke_type:, name: display_artist_name)
  if display_artist && circle.present?
    @circle = Circle.find_or_create_by(name: circle) if circle != @circle&.name
    display_artist.circles = [@circle] if @circle
  end
end

CSV.table('db/fixtures/dam_display_artist_with_circle.tsv', col_sep: "\t", converters: nil).each do |da|
  karaoke_type = da[:karaoke_type]
  display_artist_name = da[:display_artist]
  circle = da[:circle]
  display_artist = DisplayArtist.find_by(karaoke_type:, name: display_artist_name)
  if display_artist && circle.present?
    @circle = Circle.find_or_create_by(name: circle) if circle != @circle&.name
    display_artist.circles = [@circle] if @circle
  end
end

CSV.table('db/fixtures/joysound_songs_with_original_songs.tsv', col_sep: "\t", converters: nil).each do |song|
  artist = song[:artist]
  title = song[:title]
  karaoke_song = Song.includes(:display_artist).find_by(title:, display_artists: { name: artist }, karaoke_type: "JOYSOUND")
  if karaoke_song.nil?
    puts "karaoke_type: JOYSOUND, artist: #{artist}, title: #{title}, original_songs: #{song[:original_songs]}"
  else
    original_song_ids = OriginalSong.where(title: song[:original_songs].split('/'), is_duplicate: false).ids
    karaoke_song.original_song_ids = original_song_ids
  end
end

CSV.table('db/fixtures/joysound_musicpost_songs_with_original_songs.tsv', col_sep: "\t", converters: nil).each do |song|
  artist = song[:artist]
  title = song[:title]
  karaoke_song = Song.includes(:display_artist).find_by(title:, display_artists: { name: artist }, karaoke_type: "JOYSOUND(うたスキ)")
  if karaoke_song.nil?
    puts "karaoke_type: JOYSOUND(うたスキ), artist: #{artist}, title: #{title}, original_songs: #{song[:original_songs]}"
  else
    original_song_ids = OriginalSong.where(title: song[:original_songs].split('/'), is_duplicate: false).ids
    karaoke_song.original_song_ids = original_song_ids
  end
end

CSV.table('db/fixtures/dam_songs_with_original_songs.tsv', col_sep: "\t", converters: nil).each do |song|
  artist = song[:artist]
  title = song[:title]
  karaoke_song = Song.includes(:display_artist).find_by(title:, display_artists: { name: artist, karaoke_type: "DAM" }, karaoke_type: "DAM")
  if karaoke_song.nil?
    puts "karaoke_type: DAM, artist: #{artist}, title: #{title}, original_songs: #{song[:original_songs]}"
  else
    original_song_ids = OriginalSong.where(title: song[:original_songs].split('/'), is_duplicate: false).ids
    karaoke_song.original_song_ids = original_song_ids
  end
end

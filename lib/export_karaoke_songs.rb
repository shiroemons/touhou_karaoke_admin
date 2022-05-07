File.open('tmp/karaoke_songs.tsv', 'w') do |f|
  f.puts "karaoke_type\tsong_number\ttitle\turl\toriginal_songs\tyoutube_url\tnicovideo_url\tapple_music_url"
  Song.includes(:original_songs).order(:karaoke_type).each do |song|
    karaoke_type = song.karaoke_type
    song_number = song.song_number
    title = song.title
    url = song.url
    original_songs = song.original_songs.map(&:title).join('/')
    youtube_url = song.youtube_url
    nicovideo_url = song.nicovideo_url
    apple_music_url = song.apple_music_url
    # next if original_songs.present?

    f.puts "#{karaoke_type}\t#{song_number}\t#{title}\t#{url}\t#{original_songs}\t#{youtube_url}\t#{nicovideo_url}\t#{apple_music_url}"
  end
end

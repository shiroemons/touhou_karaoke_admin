require 'csv'

CSV.table('db/fixtures/touhou_music_with_youtube.tsv', col_sep: "\t", converters: nil, liberal_parsing: true).each do |tm|
  apple_track_view_url = tm[:apple_track_view_url].gsub("&uo=4", "")
  youtube_track_view_url = tm[:youtube_track_view_url]
  song = Song.find_by(apple_music_url: apple_track_view_url)
  if song && youtube_track_view_url != "不明"
    song.update(youtube_music_url: youtube_track_view_url)
  end
end
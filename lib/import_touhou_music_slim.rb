require 'csv'

# TSVファイル読み込み
touhou_music_songs = CSV.table('tmp/touhou_music_slim.tsv', col_sep: "\t", converters: nil, liberal_parsing: true)
total_count = touhou_music_songs.size

updated_count = 0
not_found_count = 0

touhou_music_songs.each.with_index(1) do |row, i|
  print "\r#{i}/#{total_count}: Progress: #{(i * 100.0 / total_count).round(1)}%"

  apple_music_url = row[:apple_music_track_url].to_s
  next if apple_music_url.blank?

  # apple_music_urlで検索
  songs = Song.where(apple_music_url: apple_music_url)

  if songs.empty?
    not_found_count += 1
    next
  end

  # 各曲を更新（空の時のみ、TSVに値がある場合のみ）
  songs.each do |song|
    updates = {}

    youtube_music_url = row[:youtube_music_track_url].to_s
    updates[:youtube_music_url] = youtube_music_url if song.youtube_music_url.blank? && youtube_music_url.present?

    spotify_url = row[:spotify_track_url].to_s
    updates[:spotify_url] = spotify_url if song.spotify_url.blank? && spotify_url.present?

    line_music_url = row[:line_music_track_url].to_s
    updates[:line_music_url] = line_music_url if song.line_music_url.blank? && line_music_url.present?

    if updates.present?
      song.update(updates)
      updated_count += 1
    end
  end
end

puts "\n完了: #{updated_count}件更新, #{not_found_count}件見つからず"

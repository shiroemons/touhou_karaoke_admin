require 'csv'
require 'json'

ORIGINAL_TYPE = {
  windows: "01. Windows作品",
  pc98: "02. PC-98作品",
  zuns_music_collection: "03. ZUN's Music Collection",
  akyus_untouched_score: "04. 幺樂団の歴史　～ Akyu's Untouched Score",
  commercial_books: "05. 商業書籍",
  other: "06. その他"
}.freeze

def first_category(original)
  ORIGINAL_TYPE[original.original_type.to_sym]
end

def second_category(original)
  "#{first_category(original)} > #{format('%#04.1f', original.series_order)}. #{original.short_title}"
end

def third_category(original_song)
  original = original_song.original
  "#{second_category(original)} > #{format('%02d', original_song.track_number)}. #{original_song.title}"
end

def original_songs_json(original_songs)
  original_songs.map do |os|
    {
      title: os.title,
      original: {
        title: os.original.title,
        short_title: os.original.short_title
      },
      'categories.lvl0': first_category(os.original),
      'categories.lvl1': second_category(os.original),
      'categories.lvl2': third_category(os)
    }
  end
end

def karaoke_delivery_models_json(song)
  song.karaoke_delivery_models.map do |kdm|
    {
      name: kdm.name,
      karaoke_type: kdm.karaoke_type
    }
  end
end

jsons = []
large_objects = []
large_object_threshold = 10 * 1024 # 10KB in bytes
one_month_ago = 1.month.ago

Song.includes(:karaoke_delivery_models, :song_with_dam_ouchikaraoke, :song_with_joysound_utasuki, display_artist: :circles, original_songs: [:original])
    .left_joins(:karaoke_delivery_models, :song_with_dam_ouchikaraoke, :song_with_joysound_utasuki)
    .where(
      'songs.karaoke_type = ? OR ' \
      'songs.updated_at >= ? OR ' \
      'karaoke_delivery_models.id IS NOT NULL AND karaoke_delivery_models.updated_at >= ? OR ' \
      'song_with_dam_ouchikaraokes.id IS NOT NULL AND song_with_dam_ouchikaraokes.updated_at >= ? OR ' \
      'song_with_joysound_utasukis.id IS NOT NULL AND song_with_joysound_utasukis.updated_at >= ?',
      'JOYSOUND(うたスキ)', one_month_ago, one_month_ago, one_month_ago, one_month_ago
    )
    .distinct
    .each do |song|
      display_artist = song.display_artist
      original_songs = song.original_songs
      next if original_songs.blank?

      original_song_titles = original_songs.map(&:title)
      next if original_song_titles.include?("オリジナル")
      next if original_song_titles.include?("その他")

      circle_name = display_artist.circles.map(&:name).join(' / ')
      json = {
        objectID: song.id,
        title: song.title,
        reading_title: song&.title_reading || '',
        display_artist: {
          name: display_artist.name,
          reading_name: display_artist.name_reading,
          reading_name_hiragana: display_artist.name_reading.tr('ァ-ン', 'ぁ-ん'),
          karaoke_type: display_artist.karaoke_type,
          url: display_artist.url
        },
        original_songs: original_songs_json(original_songs),
        karaoke_type: song.karaoke_type,
        karaoke_delivery_models: karaoke_delivery_models_json(song),
        circle: {
          name: circle_name || ''
        },
        url: song.url,
        updated_at_i: song.updated_at.to_i
      }
      json[:song_number] = song.song_number if song.song_number.present?
      if song.song_with_joysound_utasuki.present?
        musicpost = song.song_with_joysound_utasuki
        json[:delivery_deadline_date] = musicpost.delivery_deadline_date.strftime("%Y/%m/%d")
        json[:delivery_deadline_date_i] = musicpost.delivery_deadline_date.to_time.to_i
        json[:musicpost_url] = musicpost.url
      end
      if song.song_with_dam_ouchikaraoke.present?
        ouchikaraoke = song.song_with_dam_ouchikaraoke
        json[:ouchikaraoke_url] = ouchikaraoke.url
      end
      json[:videos] = []
      if song.youtube_url.present?
        m = /(?<=\?v=)(?<id>[\w\-_]+)(?!=&)/.match(song.youtube_url)
        json[:videos].push({ type: "YouTube", url: song.youtube_url, id: m[:id] })
      end
      if song.nicovideo_url.present?
        m = %r{(?<=watch/)(?<id>[s|n]m\d+)(?!=&)}.match(song.nicovideo_url)
        json[:videos].push({ type: "ニコニコ動画", url: song.nicovideo_url, id: m[:id] })
      end
      json[:touhou_music] = []
      json[:touhou_music].push({ type: "Apple Music", url: song.apple_music_url }) if song.apple_music_url.present?
      json[:touhou_music].push({ type: "YouTube Music", url: song.youtube_music_url }) if song.youtube_music_url.present?
      json[:touhou_music].push({ type: "Spotify", url: song.spotify_url }) if song.spotify_url.present?
      json[:touhou_music].push({ type: "LINE MUSIC", url: song.line_music_url }) if song.line_music_url.present?

      # オブジェクトのサイズをチェック
      json_size = JSON.generate(json).bytesize
      if json_size > large_object_threshold
        puts "警告: 「#{song.title}」(#{display_artist.name}) [ID: #{song.id}] のオブジェクトサイズが #{json_size} bytes (#{(json_size / 1024.0).round(2)}KB) で閾値を超えています"
        large_objects << {
          **json,
          _object_size_bytes: json_size,
          _object_size_kb: (json_size / 1024.0).round(2)
        }
      else
        jsons << json
      end
end

# 通常のオブジェクトをファイルに出力
File.open("tmp/karaoke_songs.json", "w") do |file|
  file.puts(JSON.pretty_generate(jsons))
end

# 大きなオブジェクトを別ファイルに出力
if large_objects.any?
  File.open("tmp/karaoke_songs_large.json", "w") do |file|
    file.puts(JSON.pretty_generate(large_objects))
  end
  puts "大きなオブジェクト #{large_objects.size} 件を tmp/karaoke_songs_large.json に出力しました"
end

puts "DAM: #{Song.dam.touhou_arrange.count}曲"
puts "JOYSOUND: #{Song.joysound.touhou_arrange.count}曲"
puts "JOYSOUND(うたスキ): #{Song.music_post.touhou_arrange.count}曲"
puts ""
puts "=== エクスポート統計 ==="
puts "通常のオブジェクト: #{jsons.size} 件"
puts "大きなオブジェクト (10KB超): #{large_objects.size} 件"
puts "合計: #{jsons.size + large_objects.size} 件"
puts ""

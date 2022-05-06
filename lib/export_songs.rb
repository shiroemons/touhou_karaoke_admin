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
Song.includes(:display_artist, :karaoke_delivery_models, original_songs: [:original]).each do |song|
  display_artist = song.display_artist
  original_songs = song.original_songs
  original_song_titles = original_songs.map(&:title)
  next if original_song_titles.include?("オリジナル")
  next if original_song_titles.include?("その他")

  circle = display_artist.circles.first
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
      name: circle&.name || ''
    },
    url: song.url
  }
  json[:song_number] = song.song_number if song.song_number.present?
  if song.song_with_joysound_utasuki.present?
    musicpost = song.song_with_joysound_utasuki
    json[:delivery_deadline_date] = musicpost.delivery_deadline_date.strftime("%Y/%m/%d")
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
  jsons << json
end

File.open("tmp/karaoke_songs.json", "w") do |file|
  file.puts(JSON.pretty_generate(jsons))
end

puts "DAM: #{Song.dam.touhou_arrange.count}曲"
puts "JOYSOUND: #{Song.joysound.touhou_arrange.count}曲"
puts "JOYSOUND(うたスキ): #{Song.music_post.touhou_arrange.count}曲"
puts ""

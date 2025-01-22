# frozen_string_literal: true

class ImportSongsWithOriginalSongs < Avo::BaseAction
  self.name = '原曲を含む楽曲のインポート'
  self.standalone = true
  self.visible = -> { view == :index }

  field :tsv_file, as: :file, accept: 'text/tab-separated-values'

  def handle(**args)
    field = args.values_at(:fields).first

    fail('Import error.') unless field['tsv_file']&.content_type&.in?(['text/tab-separated-values'])

    songs = CSV.table(field['tsv_file'].path, col_sep: "\t", converters: nil, liberal_parsing: true)
    songs.each do |s|
      id = s[:id]
      youtube_url = s[:youtube_url].to_s
      nicovideo_url = s[:nicovideo_url].to_s
      original_songs = s[:original_songs].to_s
      apple_music_url = s[:apple_music_url].to_s
      youtube_music_url = s[:youtube_music_url].to_s
      spotify_url = s[:spotify_url].to_s
      line_music_url = s[:line_music_url].to_s
      song = Song.find_by(id:)
      next unless song.present? && original_songs.present?

      original_song_list = OriginalSong.where(title: original_songs.split('/'), is_duplicate: false)
      song.original_songs = original_song_list
      song.youtube_url = youtube_url
      song.nicovideo_url = nicovideo_url
      song.apple_music_url = apple_music_url
      song.youtube_music_url = youtube_music_url
      song.spotify_url = spotify_url
      song.line_music_url = line_music_url
      song.save
    end
    succeed('Completed!')
    reload
  end
end

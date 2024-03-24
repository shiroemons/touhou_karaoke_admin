# frozen_string_literal: true

class ExportMissingOriginalSongs < Avo::BaseAction
  self.name = 'Export missing original songs'
  self.standalone = true
  self.visible = -> { view == :index }
  self.may_download_file = true

  def handle(_args)
    tsv_data = CSV.generate(col_sep: "\t") do |csv|
      csv << %w[id karaoke_type display_artist_name title original_songs youtube_url nicovideo_url apple_music_url youtube_music_url spotify_url line_music_url]
      Song.includes(:display_artist, :original_songs).missing_original_songs.order('display_artists.name asc').order(title: :asc).each do |song|
        column_values = [
          song.id,
          song.karaoke_type,
          song.display_artist.name,
          song.title,
          song.original_songs.map(&:title).join('/'),
          song.youtube_url,
          song.nicovideo_url,
          song.apple_music_url,
          song.youtube_music_url,
          song.spotify_url,
          song.line_music_url
        ]
        csv << column_values
      end
    end

    download tsv_data, 'missing_original_songs.tsv'
  end
end

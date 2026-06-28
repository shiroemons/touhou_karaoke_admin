module Admin
  module KaraokeSongUrlPlaceholderHelper
    URL_PLACEHOLDERS = {
      'youtube_url' => 'https://www.youtube.com/watch?v=...',
      'nicovideo_url' => 'https://www.nicovideo.jp/watch/sm...',
      'apple_music_url' => 'https://music.apple.com/jp/album/.../...',
      'youtube_music_url' => 'https://music.youtube.com/watch?v=...',
      'spotify_url' => 'https://open.spotify.com/track/...',
      'line_music_url' => 'https://music.line.me/webapp/track/...'
    }.freeze

    def karaoke_song_url_placeholder(column)
      URL_PLACEHOLDERS.fetch(column.to_s, 'https://example.com/...')
    end
  end
end

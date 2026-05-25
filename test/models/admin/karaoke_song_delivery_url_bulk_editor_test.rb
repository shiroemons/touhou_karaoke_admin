require 'test_helper'

module Admin
  class KaraokeSongDeliveryUrlBulkEditorTest < ActiveSupport::TestCase
    test 'updates delivery urls from form rows without changing original songs' do
      song = create_song(title: 'Delivery URL Form Song')
      original_song = create_original_song(title: 'Delivery URL Original')
      song.original_songs << original_song

      result = KaraokeSongDeliveryUrlBulkEditor.new(actor_name: '管理者').update_from_form_rows(
        song.id => {
          'youtube_url' => ' https://youtube.example/watch ',
          'nicovideo_url' => '',
          'apple_music_url' => 'https://music.apple.example/song',
          'youtube_music_url' => '',
          'spotify_url' => 'https://open.spotify.example/track',
          'line_music_url' => 'https://music.line.example/track'
        }
      )

      assert_empty result.errors
      assert_equal 1, result.updated_count
      assert_equal [original_song], song.reload.original_songs.to_a
      assert_equal 'https://youtube.example/watch', song.youtube_url
      assert_equal 'https://music.apple.example/song', song.apple_music_url
      assert_equal 'https://open.spotify.example/track', song.spotify_url
      assert_equal 'https://music.line.example/track', song.line_music_url
    end

    test 'previews delivery url changes without updating records' do
      song = create_song(title: 'Delivery URL Preview Song', youtube_url: '')

      result = KaraokeSongDeliveryUrlBulkEditor.new(actor_name: '管理者').preview_from_form_rows(
        song.id => {
          'youtube_url' => 'https://youtube.example/preview',
          'nicovideo_url' => '',
          'apple_music_url' => '',
          'youtube_music_url' => '',
          'spotify_url' => '',
          'line_music_url' => ''
        }
      )

      assert_empty result.errors
      assert_equal 1, result.checked_count
      assert_equal ['youtube_url'], result.rows.first.fetch(:changed_url_columns)
      assert_equal 'https://youtube.example/preview', result.rows.first.dig(:url_changes, 'youtube_url', :after)
      assert_equal '', song.reload.youtube_url
    end

    test 'updates delivery urls from tsv columns' do
      song = create_song(title: 'Delivery URL TSV Song')
      tsv = [
        KaraokeSongDeliveryUrlBulkEditor::COLUMNS.join("\t"),
        [
          song.id,
          song.karaoke_type,
          song.display_artist.name,
          song.title,
          '',
          '',
          'https://nico.example/watch',
          '',
          'https://music.youtube.example/watch',
          '',
          ''
        ].join("\t")
      ].join("\n")

      result = KaraokeSongDeliveryUrlBulkEditor.new(actor_name: '管理者').update_from_tsv(tsv)

      assert_empty result.errors
      assert_equal 1, result.updated_count
      assert_equal 'https://nico.example/watch', song.reload.nicovideo_url
      assert_equal 'https://music.youtube.example/watch', song.youtube_music_url
    end

    test 'does not update any rows when a tsv song id cannot be resolved' do
      song = create_song(title: 'Delivery URL Blocked Song', youtube_url: '')
      tsv = [
        KaraokeSongDeliveryUrlBulkEditor::COLUMNS.join("\t"),
        [
          'missing-song-id',
          song.karaoke_type,
          song.display_artist.name,
          song.title,
          '',
          'https://youtube.example/blocked',
          '',
          '',
          '',
          '',
          ''
        ].join("\t")
      ].join("\n")

      result = KaraokeSongDeliveryUrlBulkEditor.new(actor_name: '管理者').update_from_tsv(tsv)

      assert_equal 1, result.errors.size
      assert_match(/missing-song-id/, result.errors.first)
      assert_equal '', song.reload.youtube_url
    end
  end
end

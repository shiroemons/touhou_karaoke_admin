require 'test_helper'

module Admin
  class KaraokeSongBulkEditorTest < ActiveSupport::TestCase
    test 'updates original songs and delivery urls from form rows' do
      song = create_song(title: 'Bulk Edit Song')
      original_song = create_original_song(title: 'Bulk Edit Original')

      result = KaraokeSongBulkEditor.new(actor_name: '管理者').update_from_form_rows(
        song.id => {
          'original_songs' => original_song.title,
          'youtube_url' => ' https://youtube.example/watch ',
          'nicovideo_url' => '',
          'apple_music_url' => '',
          'youtube_music_url' => '',
          'spotify_url' => '',
          'line_music_url' => ''
        }
      )

      assert_empty result.errors
      assert_equal 1, result.updated_count
      assert_equal [original_song], song.reload.original_songs.to_a
      assert_equal 'https://youtube.example/watch', song.youtube_url
    end

    test 'updates rows from exported tsv columns' do
      song = create_song(title: 'TSV Bulk Song')
      original_song = create_original_song(title: 'TSV Bulk Original')
      tsv = [
        KaraokeSongBulkEditor::COLUMNS.join("\t"),
        [
          song.id,
          song.karaoke_type,
          song.display_artist.name,
          song.title,
          original_song.title,
          '',
          'https://nico.example/watch',
          '',
          '',
          '',
          ''
        ].join("\t")
      ].join("\n")

      result = KaraokeSongBulkEditor.new(actor_name: '管理者').update_from_tsv(tsv)

      assert_empty result.errors
      assert_equal 1, result.updated_count
      assert_equal [original_song], song.reload.original_songs.to_a
      assert_equal 'https://nico.example/watch', song.nicovideo_url
    end

    test 'does not update any rows when an original song title cannot be resolved' do
      song = create_song(youtube_url: '')
      valid_original_song = create_original_song(title: 'Valid Bulk Original')

      result = KaraokeSongBulkEditor.new(actor_name: '管理者').update_from_form_rows(
        song.id => {
          'original_songs' => "#{valid_original_song.title}/Missing Bulk Original",
          'youtube_url' => 'https://youtube.example/blocked'
        }
      )

      assert_equal 1, result.errors.size
      assert_match(/Missing Bulk Original/, result.errors.first)
      assert_empty song.reload.original_songs
      assert_equal '', song.youtube_url
    end

    test 'keeps delimiters inside known original song titles when splitting pasted text' do
      song = create_song
      delimiter_original_song = create_original_song(title: '幽雅に咲かせ、墨染の桜　～ Border of Life')
      other_original_song = create_original_song(title: '妖魔夜行')

      result = KaraokeSongBulkEditor.new(actor_name: '管理者').update_from_form_rows(
        song.id => {
          'original_songs' => "#{delimiter_original_song.title}、#{other_original_song.title}"
        }
      )

      assert_empty result.errors
      assert_equal [delimiter_original_song.code, other_original_song.code].sort, song.reload.original_songs.map(&:code).sort
    end
  end
end

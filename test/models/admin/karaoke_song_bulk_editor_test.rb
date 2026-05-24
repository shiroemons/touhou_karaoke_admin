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

    test 'resolves multiple original songs with minor title notation differences' do
      song = create_song
      stone_goddess = create_original_song(title: '最後の一人は慣れてるから　～ Stone Goddess')
      owen = create_original_song(title: 'U.N.オーエンは彼女なのか？')

      result = KaraokeSongBulkEditor.new(actor_name: '管理者').preview_from_form_rows(
        song.id => {
          'original_songs' => '最後の一人は慣れてるから 〜Stone Goddess / U.N.オーエンは彼女なのか?'
        }
      )

      assert_empty result.errors
      resolved_titles = result.rows.first.fetch(:original_songs).map { |item| item.fetch(:title) }
      assert_equal [stone_goddess.title, owen.title], resolved_titles
      assert_empty song.reload.original_songs
    end

    test 'searches original song options with normalized title notation' do
      original_song = create_original_song(title: '最後の一人は慣れてるから　～ Stone Goddess')

      results = KaraokeSongBulkEditor.search_original_song_options('最後の一人は慣れてるから 〜Stone')

      assert_includes results, original_song
    end

    test 'does not return partially resolved titles for picker text' do
      create_original_song(title: 'U.N.オーエンは彼女なのか？')

      result = KaraokeSongBulkEditor.new(actor_name: '管理者').resolve_original_song_titles(
        'Missing Original / U.N.オーエンは彼女なのか?'
      )

      assert_empty result.fetch(:titles)
      assert_equal [
        { input_title: 'Missing Original', title: 'Missing Original', exists: false, error: '原曲「Missing Original」が見つかりません。' },
        { input_title: 'U.N.オーエンは彼女なのか?', title: 'U.N.オーエンは彼女なのか？', exists: true, error: nil }
      ], result.fetch(:items)
      assert_equal 1, result.fetch(:errors).size
      assert_match(/Missing Original/, result.fetch(:errors).first)
    end

    test 'previews each resolved original song without updating records' do
      song = create_song
      first_original_song = create_original_song(title: 'Preview First Original')
      second_original_song = create_original_song(title: 'Preview Second Original')

      result = KaraokeSongBulkEditor.new(actor_name: '管理者').preview_from_form_rows(
        song.id => {
          'original_songs' => "#{first_original_song.title}/#{second_original_song.title}",
          'youtube_url' => 'https://youtube.example/preview'
        }
      )

      assert_empty result.errors
      assert_equal 1, result.checked_count
      resolved_titles = result.rows.first.fetch(:original_songs).map { |item| item.fetch(:title) }
      assert_equal [first_original_song.title, second_original_song.title], resolved_titles
      assert_equal ['youtube_url'], result.rows.first.fetch(:changed_url_columns)
      assert_empty song.reload.original_songs
      assert_equal '', song.youtube_url
    end
  end
end

require 'test_helper'

module Admin
  class SongsControllerTest < ActionDispatch::IntegrationTest
    test 'show page renders the original song picker with the current chips' do
      original_song = create_original_song(title: 'Show Page Original')
      song = create_song
      song.original_songs = [original_song]

      get admin_song_path(song)

      assert_response :success
      assert_select '[data-admin-association-dialog-trigger="song-original-songs"]', text: /紐づけ/
      assert_select 'dialog[data-admin-association-dialog="song-original-songs"]' do
        assert_select '[data-admin-original-song-picker]'
        assert_select '[data-admin-original-song-picker-status][role="status"][aria-live="polite"][aria-atomic="true"]'
        assert_select 'input[type="hidden"][name="original_songs"][value=?][data-admin-original-song-value]', original_song.title
        assert_select 'form[action=?][method="post"]', original_songs_admin_song_path(song) do
          assert_select 'input[name="_method"][value="patch"]', 1
        end
      end
    end

    test 'original_songs action links a resolved original song and redirects to show' do
      song = create_song(youtube_url: 'https://youtube.example/keep')
      original_song = create_original_song(title: 'Controller Link Original')

      with_cache_store(ActiveSupport::Cache::MemoryStore.new) do
        Rails.cache.write(DashboardCache::KEY, { total_songs: 1 })

        assert_difference -> { Admin::ChangeLog.count }, 1 do
          patch original_songs_admin_song_path(song), params: { original_songs: original_song.title }
        end

        assert_not Rails.cache.exist?(DashboardCache::KEY)
      end

      assert_redirected_to admin_song_path(song)
      follow_redirect!
      assert_select '.admin-flash-notice', text: '原曲紐づけを更新しました。'
      song.reload
      assert_equal [original_song], song.original_songs.to_a
      assert_equal 'https://youtube.example/keep', song.youtube_url
    end

    test 'original_songs action replaces existing links with the submitted chip set' do
      existing_original_song = create_original_song(title: 'Existing Controller Original')
      additional_original_song = create_original_song(title: 'Additional Controller Original')
      song = create_song
      song.original_songs = [existing_original_song]

      patch original_songs_admin_song_path(song), params: {
        original_songs: "#{existing_original_song.title}/#{additional_original_song.title}"
      }

      assert_redirected_to admin_song_path(song)
      assert_equal [existing_original_song.code, additional_original_song.code].sort, song.reload.original_songs.map(&:code).sort
    end

    test 'original_songs action redirects with an alert when a title cannot be resolved' do
      song = create_song

      patch original_songs_admin_song_path(song), params: { original_songs: 'Missing Controller Original' }

      assert_redirected_to admin_song_path(song)
      follow_redirect!
      assert_select '.admin-flash-alert', text: /Missing Controller Original/
      assert_empty song.reload.original_songs
    end

    private

    def with_cache_store(store)
      original_cache = Rails.cache
      Rails.cache = store
      yield
    ensure
      store.clear
      Rails.cache = original_cache
    end
  end
end

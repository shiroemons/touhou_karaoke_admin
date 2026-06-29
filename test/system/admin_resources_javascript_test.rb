# frozen_string_literal: true

require 'application_system_test_case'

class AdminResourcesJavascriptTest < ApplicationSystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 900]

  setup do
    artist = create_display_artist(name: 'System JS Artist')
    @song = create_song(display_artist: artist, title: 'System JS Karaoke Song')
    @dam_artist = create_display_artist(karaoke_type: 'DAM', name: 'System JS DAM Artist')
    @dam_song = DamSong.create!(display_artist: @dam_artist, title: 'System JS DAM Candidate', url: "#{Constants::Karaoke::Dam::SONG_URL}existing")
  end

  test 'selection required operation modal updates submit state with JavaScript' do
    visit admin_songs_path(view_mode: 'paginated')

    find('.admin-operation-guide-summary').click
    find('[data-admin-operation-trigger][data-admin-operation-key="export_songs"]').click

    within('[data-admin-operation-panel="export_songs"]') do
      assert_selector '[data-admin-operation-selection-count]', text: '0'
      assert_selector '[data-admin-operation-selection-note]', text: '対象を選択してください。'
      assert_selector '[data-admin-operation-submit][disabled]'
    end

    find('[data-admin-operation-modal-close]').click
    assert_no_selector '[data-admin-operation-modal][open]'
    find("[data-admin-resource-select][value='#{@song.id}']").check
    find('.admin-operation-guide-summary').click unless page.has_selector?('[data-admin-operation-trigger][data-admin-operation-key="export_songs"]')
    find('[data-admin-operation-trigger][data-admin-operation-key="export_songs"]').click

    within('[data-admin-operation-panel="export_songs"]') do
      assert_selector '[data-admin-operation-selection-count]', text: '1'
      assert_selector '[data-admin-operation-selection-note]', text: '選択した対象で実行できます。'
      assert_no_selector '[data-admin-operation-submit][disabled]'
    end
  end

  test 'async operation modal validates required input starts progress and completes' do
    visit operation_admin_dam_songs_path(operation: 'fetch_dam_song')

    assert_selector '[data-admin-operation-submit][disabled]'
    fill_in 'DAM楽曲URL', with: "#{Constants::Karaoke::Dam::SONG_URL}123456"
    assert_no_selector '[data-admin-operation-submit][disabled]'

    progress_id = find("input[name='operation_progress_id']", visible: :hidden).value
    find('[data-admin-operation-submit]').click

    assert_selector '[data-admin-operation-progress][hidden]', visible: :hidden
    assert_text '指定URLからDAM候補を追加します。実行しますか？'
    find('[data-admin-operation-confirm]').click

    assert_selector '[data-admin-operation-progress]:not([hidden])'
    assert_selector '[data-admin-operation-progress-status]', text: /確認中|待機中|外部サイト取得中/

    Admin::OperationProgress.complete!(progress_id, label: 'DAM候補を追加しました', detail: '処理が完了しました')

    assert_selector '[data-admin-operation-progress-status]', text: '完了', wait: 3
    assert_selector '[data-admin-operation-progress-percent]', text: '100%'
  end

  test 'resource selection handlers work after async index replacement' do
    visit admin_songs_path(view_mode: 'paginated')

    find('.admin-sort-link', text: 'タイトル').click
    assert_selector '.admin-sort-link-active', text: 'タイトル'

    find("[data-admin-resource-select][value='#{@song.id}']").check
    find('.admin-operation-guide-summary').click
    find('[data-admin-operation-trigger][data-admin-operation-key="export_songs"]').click

    within('[data-admin-operation-panel="export_songs"]') do
      assert_selector '[data-admin-operation-selection-count]', text: '1'
      assert_selector '[data-admin-operation-selection-note]', text: '選択した対象で実行できます。'
      assert_no_selector '[data-admin-operation-submit][disabled]'
    end
  end
end

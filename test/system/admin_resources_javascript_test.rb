# frozen_string_literal: true

require 'application_system_test_case'

class AdminResourcesJavascriptTest < ApplicationSystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 900]

  setup do
    artist = create_display_artist(name: 'System JS Artist')
    @song = create_song(display_artist: artist, title: 'System JS Karaoke Song')
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
end

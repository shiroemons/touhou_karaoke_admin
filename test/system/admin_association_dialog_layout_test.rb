# frozen_string_literal: true

require 'application_system_test_case'

class AdminAssociationDialogLayoutTest < ApplicationSystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 900]

  setup do
    artist = create_display_artist(name: 'Responsive Association Artist')
    @song = create_song(display_artist: artist, title: 'Responsive Association Song')
  end

  test 'original song association dialog stays inside a narrow viewport' do
    visit admin_song_path(@song)
    resize_browser(320, 812)
    find('[data-admin-association-dialog-trigger="song-original-songs"]').click

    metrics = page.execute_script(<<~JS)
      const modal = document.querySelector('.admin-association-dialog-box');
      const picker = document.querySelector('.admin-original-song-picker');
      const actions = document.querySelector('.admin-association-dialog-form .admin-form-actions');

      return {
        viewportWidth: window.innerWidth,
        rootOverflow: document.documentElement.scrollWidth > window.innerWidth,
        modalRight: modal.getBoundingClientRect().right,
        pickerRight: picker.getBoundingClientRect().right,
        actionsRight: actions.getBoundingClientRect().right
      };
    JS

    assert_operator metrics.fetch('viewportWidth'), :<, 860
    assert_equal false, metrics.fetch('rootOverflow')
    assert_operator metrics.fetch('modalRight'), :<=, metrics.fetch('viewportWidth')
    assert_operator metrics.fetch('pickerRight'), :<=, metrics.fetch('viewportWidth')
    assert_operator metrics.fetch('actionsRight'), :<=, metrics.fetch('viewportWidth')
  end

  private

  def resize_browser(width, height)
    page.driver.browser.manage.window.resize_to(width, height)
  end
end

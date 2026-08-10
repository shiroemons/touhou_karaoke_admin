# frozen_string_literal: true

require 'application_system_test_case'

class AdminViewModeLayoutTest < ApplicationSystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 900]

  setup do
    artist = create_display_artist(name: 'Responsive View Mode Artist')
    create_song(display_artist: artist, title: 'Responsive View Mode Song')
  end

  test 'mobile display mode controls fill the available width' do
    visit admin_songs_path(view_mode: 'infinite')
    resize_browser(375, 812)

    metrics = page.execute_script(<<~JS)
      const settings = document.querySelector('.admin-table-display-settings');
      const group = document.querySelector('.admin-view-mode-group');
      const pageOption = document.querySelector('.admin-view-mode-option-docked');
      const pageButton = pageOption.querySelector('.admin-view-mode-button');

      return {
        rootOverflow: document.documentElement.scrollWidth > window.innerWidth,
        controlsWidth: document.querySelector('.admin-table-controls').getBoundingClientRect().width,
        settingsWidth: settings.getBoundingClientRect().width,
        groupWidth: group.getBoundingClientRect().width,
        groupRight: group.getBoundingClientRect().right,
        pageOptionRight: pageOption.getBoundingClientRect().right,
        pageButtonWidth: pageButton.getBoundingClientRect().width
      };
    JS

    assert_equal false, metrics.fetch('rootOverflow')
    assert_in_delta metrics.fetch('controlsWidth'), metrics.fetch('settingsWidth'), 1
    assert_in_delta metrics.fetch('settingsWidth'), metrics.fetch('groupWidth'), 1
    assert_in_delta metrics.fetch('groupRight'), metrics.fetch('pageOptionRight'), 1
    assert_operator metrics.fetch('pageButtonWidth'), :>, 150
  end

  private

  def resize_browser(width, height)
    page.driver.browser.manage.window.resize_to(width, height)
  end
end

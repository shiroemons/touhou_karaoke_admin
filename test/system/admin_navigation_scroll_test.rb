# frozen_string_literal: true

require 'application_system_test_case'

class AdminNavigationScrollTest < ApplicationSystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 900]

  setup do
    artist = create_display_artist(name: 'Responsive Navigation Artist')
    @song = create_song(display_artist: artist, title: 'Responsive Navigation Song')
  end

  test 'mobile row navigation starts the detail page at the top' do
    visit admin_songs_path(view_mode: 'paginated')
    resize_browser(320, 812)
    click_on @song.title

    assert_current_path admin_song_path(@song), ignore_query: true
    assert_operator page.execute_script('return window.scrollY'), :<=, 1
    assert_selector 'h1', text: @song.title
  end

  private

  def resize_browser(width, height)
    page.driver.browser.manage.window.resize_to(width, height)
  end
end

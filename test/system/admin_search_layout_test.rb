# frozen_string_literal: true

require 'application_system_test_case'

class AdminSearchLayoutTest < ApplicationSystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 900]

  setup do
    artist = create_display_artist(name: 'Responsive Search Artist')
    create_song(display_artist: artist, title: 'Responsive Search Song')
  end

  test 'search actions stay inline on desktop and stack on mobile' do
    visit admin_songs_path(view_mode: 'paginated')

    resize_browser(900, 900)
    desktop_search = search_layout_metrics
    assert_equal 1, desktop_search.fetch('tops').uniq.length
    assert_equal false, desktop_search.fetch('rootOverflow')

    resize_browser(375, 812)
    mobile_search = search_layout_metrics
    assert_equal 3, mobile_search.fetch('tops').uniq.length
    assert_equal false, mobile_search.fetch('rootOverflow')
  end

  private

  def resize_browser(width, height)
    page.driver.browser.manage.window.resize_to(width, height)
  end

  def search_layout_metrics
    page.execute_script(<<~JS)
      return {
        tops: [...document.querySelectorAll('.admin-search-row-inline > *')].map((element) => Math.round(element.getBoundingClientRect().top)),
        rootOverflow: document.documentElement.scrollWidth > window.innerWidth
      };
    JS
  end
end

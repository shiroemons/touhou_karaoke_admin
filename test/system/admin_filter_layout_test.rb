# frozen_string_literal: true

require 'application_system_test_case'

class AdminFilterLayoutTest < ApplicationSystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 900]

  setup do
    artist = create_display_artist(name: 'Responsive Filter Artist')
    create_song(display_artist: artist, title: 'Responsive Filter Song')
  end

  test 'presence filters fit without horizontal scrolling at compact widths' do
    visit admin_songs_path(view_mode: 'paginated')
    page.execute_script("document.querySelector('[data-admin-filter-disclosure]').open = true")
    resize_browser(320, 812)

    metrics = page.execute_script(<<~JS)
      const filterList = document.querySelector('.admin-filter-list');
      const filterRect = filterList.getBoundingClientRect();

      return {
        rootOverflow: document.documentElement.scrollWidth > window.innerWidth,
        filterOverflow: filterList.scrollWidth > filterList.clientWidth,
        rowsInsideFilter: [...filterList.querySelectorAll('.admin-presence-filter-row')].every((row) => {
          const rowRect = row.getBoundingClientRect();

          return rowRect.left >= filterRect.left - 1 && rowRect.right <= filterRect.right + 1;
        })
      };
    JS

    assert_equal false, metrics.fetch('rootOverflow')
    assert_equal false, metrics.fetch('filterOverflow')
    assert_equal true, metrics.fetch('rowsInsideFilter')
  end

  private

  def resize_browser(width, height)
    page.driver.browser.manage.window.resize_to(width, height)
  end
end

# frozen_string_literal: true

require 'application_system_test_case'

class AdminTableStickyColumnsTest < ApplicationSystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 900]

  setup do
    create_original_song(is_duplicate: false)
  end

  test 'sticky action cells hide horizontally scrolled content' do
    visit admin_original_songs_path
    resize_browser(768, 900)

    metrics = page.execute_script(<<~JS)
      const wrap = document.querySelector('.admin-table-wrap');
      const row = document.querySelector('.admin-table tbody tr');
      const stickyCells = [...row.querySelectorAll('.admin-select-column, .admin-actions-column')];

      wrap.scrollLeft = wrap.scrollWidth - wrap.clientWidth;

      return {
        rootOverflow: document.documentElement.scrollWidth > window.innerWidth,
        tableOverflow: wrap.scrollWidth > wrap.clientWidth,
        stickyCellBackgrounds: stickyCells.map((cell) => getComputedStyle(cell).backgroundColor),
        actionLinkInsideCell: (() => {
          const cell = row.querySelector('.admin-actions-column');
          const link = cell.querySelector('a, button');
          const cellRect = cell.getBoundingClientRect();
          const linkRect = link.getBoundingClientRect();

          return linkRect.left >= cellRect.left && linkRect.right <= cellRect.right;
        })()
      };
    JS

    assert_equal false, metrics.fetch('rootOverflow')
    assert_equal true, metrics.fetch('tableOverflow')
    assert metrics.fetch('stickyCellBackgrounds').all? { |color| color != 'rgba(0, 0, 0, 0)' }, metrics
    assert_equal true, metrics.fetch('actionLinkInsideCell')
  end

  private

  def resize_browser(width, height)
    browser = page.driver.browser
    browser.manage.window.resize_to(width, height)
    browser.execute_cdp(
      'Emulation.setDeviceMetricsOverride',
      width:,
      height:,
      deviceScaleFactor: 1,
      mobile: false
    )
  end
end

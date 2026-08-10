# frozen_string_literal: true

require 'application_system_test_case'

class AdminDashboardManagementLayoutTest < ApplicationSystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 900]

  test 'management cards stay inside the dashboard content at narrow widths' do
    visit admin_root_path
    resize_browser(320, 812)

    metrics = page.execute_script(<<~JS)
      const main = document.querySelector('.admin-main');
      const grid = document.querySelector('.admin-dashboard-management-grid');
      const mainRect = main.getBoundingClientRect();
      const gridRect = grid.getBoundingClientRect();

      return {
        rootOverflow: document.documentElement.scrollWidth > window.innerWidth,
        gridInsideMain: gridRect.left >= mainRect.left - 1 && gridRect.right <= mainRect.right + 1,
        panelsInsideGrid: [...grid.querySelectorAll('.admin-dashboard-management-panel')].every((panel) => {
          const panelRect = panel.getBoundingClientRect();

          return panelRect.left >= gridRect.left - 1 && panelRect.right <= gridRect.right + 1;
        })
      };
    JS

    assert_equal false, metrics.fetch('rootOverflow')
    assert_equal true, metrics.fetch('gridInsideMain')
    assert_equal true, metrics.fetch('panelsInsideGrid')
  end

  private

  def resize_browser(width, height)
    page.driver.browser.manage.window.resize_to(width, height)
  end
end

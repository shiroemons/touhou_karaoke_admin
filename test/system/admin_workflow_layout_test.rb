# frozen_string_literal: true

require 'application_system_test_case'

class AdminWorkflowLayoutTest < ApplicationSystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 900]

  test 'workflow group headings and run links remain usable on mobile' do
    visit admin_workflow_path
    resize_browser(320, 812)

    metrics = page.execute_script(<<~JS)
      const groups = [...document.querySelectorAll('.admin-workflow-group')];
      const headers = groups
        .map((group) => group.querySelector(':scope > header'))
        .filter((header) => header.querySelector('.admin-workflow-run-link'));

      return {
        rootOverflow: document.documentElement.scrollWidth > window.innerWidth,
        headingsReadable: headers.every((header) => {
          const heading = header.querySelector('h2');

          return heading.getBoundingClientRect().width >= 100;
        }),
        runLinksInsideHeader: headers.every((header) => {
          const headerRect = header.getBoundingClientRect();
          const runRect = header.querySelector('.admin-workflow-run-link').getBoundingClientRect();

          return runRect.left >= headerRect.left - 1 && runRect.right <= headerRect.right + 1;
        })
      };
    JS

    assert_equal false, metrics.fetch('rootOverflow')
    assert_equal true, metrics.fetch('headingsReadable')
    assert_equal true, metrics.fetch('runLinksInsideHeader')
  end

  test 'workflow step actions do not overlap their descriptions on mobile' do
    visit admin_workflow_steps_path('music_post')
    resize_browser(320, 812)

    metrics = page.execute_script(<<~JS)
      const steps = [...document.querySelectorAll('.admin-workflow-step')];

      return {
        rootOverflow: document.documentElement.scrollWidth > window.innerWidth,
        actionsInsideSteps: steps.every((step) => {
          const stepRect = step.getBoundingClientRect();
          const actionRect = step.querySelector('.admin-button').getBoundingClientRect();

          return actionRect.left >= stepRect.left - 1 && actionRect.right <= stepRect.right + 1;
        }),
        actionsBelowBody: steps.every((step) => {
          const bodyRect = step.querySelector('.admin-workflow-step-body').getBoundingClientRect();
          const actionRect = step.querySelector('.admin-button').getBoundingClientRect();

          return actionRect.top >= bodyRect.bottom - 1;
        })
      };
    JS

    assert_equal false, metrics.fetch('rootOverflow')
    assert_equal true, metrics.fetch('actionsInsideSteps')
    assert_equal true, metrics.fetch('actionsBelowBody')
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

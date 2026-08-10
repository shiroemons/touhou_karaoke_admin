# frozen_string_literal: true

require 'application_system_test_case'

class AdminRelatedSectionsLayoutTest < ApplicationSystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 900]

  setup do
    artist = create_display_artist(name: 'Responsive Related Artist')
    @song = create_song(display_artist: artist, title: 'Responsive Related Song')
  end

  test 'related data sections do not overflow the detail card on mobile' do
    visit admin_song_path(@song)
    resize_browser(320, 812)

    metrics = page.execute_script(<<~JS)
      const related = document.querySelector('.admin-related-sections');

      return {
        rootOverflow: document.documentElement.scrollWidth > window.innerWidth,
        relatedOverflow: related.scrollWidth > related.clientWidth,
        sectionInsideRelated: [...related.querySelectorAll('.admin-related-section')].every((section) => {
          return section.getBoundingClientRect().right <= related.getBoundingClientRect().right + 1;
        })
      };
    JS

    assert_equal false, metrics.fetch('rootOverflow')
    assert_equal false, metrics.fetch('relatedOverflow')
    assert_equal true, metrics.fetch('sectionInsideRelated')
  end

  private

  def resize_browser(width, height)
    page.driver.browser.manage.window.resize_to(width, height)
  end
end

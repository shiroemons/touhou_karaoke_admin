# frozen_string_literal: true

require 'application_system_test_case'

class AdminDashboardDetailLayoutTest < ApplicationSystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 900]

  setup do
    artist = create_display_artist(name: 'Responsive Detail Artist')
    @song = create_song(
      display_artist: artist,
      title: 'Responsive Detail Song',
      url: 'https://www.joysound.com/web/search/song/1193986',
      youtube_url: 'https://www.youtube.com/watch?v=Io0avJnN4Vo'
    )
  end

  test 'dashboard insight group content starts at a consistent vertical position' do
    visit admin_root_path
    resize_browser(1920, 1080)

    offsets = page.execute_script(<<~JS)
      return [...document.querySelectorAll('.admin-dashboard-insight-group')].map((group) => {
        const groupTop = group.getBoundingClientRect().top;
        const headingTop = group.querySelector('h3').getBoundingClientRect().top;
        const descriptionTop = group.querySelector('p').getBoundingClientRect().top;
        const cardsTop = group.querySelector('.admin-insight-grid').getBoundingClientRect().top;

        return [headingTop - groupTop, descriptionTop - groupTop, cardsTop - groupTop].map(Math.round);
      });
    JS

    assert_equal 1, offsets.uniq.length
  end

  test 'detail URLs and rows remain inside the content area across breakpoints' do
    visit admin_song_path(@song)

    resize_browser(900, 900)
    desktop_detail = detail_layout_metrics
    assert_equal desktop_detail.fetch('mainClient'), desktop_detail.fetch('mainScroll')
    assert desktop_detail.fetch('urlsInsideMain')

    resize_browser(375, 812)
    mobile_detail = detail_layout_metrics
    assert_equal mobile_detail.fetch('mainClient'), mobile_detail.fetch('mainScroll')
    assert mobile_detail.fetch('urlsInsideMain')
    assert_equal 'grid', mobile_detail.fetch('heroDisplay')
    assert mobile_detail.fetch('detailRowsSingleColumn')
  end

  private

  def resize_browser(width, height)
    page.driver.browser.manage.window.resize_to(width, height)
  end

  def detail_layout_metrics
    page.execute_script(<<~JS)
      const main = document.querySelector('.admin-main');
      const mainRect = main.getBoundingClientRect();
      const rows = [...document.querySelectorAll('.admin-detail-row')];
      const urlsInsideMain = [...document.querySelectorAll('.admin-url')].every((element) => {
        return element.getBoundingClientRect().right <= mainRect.right + 1;
      });

      return {
        mainClient: main.clientWidth,
        mainScroll: main.scrollWidth,
        urlsInsideMain,
        heroDisplay: getComputedStyle(document.querySelector('.admin-detail-hero')).display,
        detailRowsSingleColumn: rows.every((row) => getComputedStyle(row).gridTemplateColumns.split(' ').length === 1)
      };
    JS
  end
end

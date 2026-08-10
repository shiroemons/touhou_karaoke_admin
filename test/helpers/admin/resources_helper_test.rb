require 'test_helper'

module Admin
  class ResourcesHelperTest < ActionView::TestCase
    include ResourcesHelper

    test 'url values announce that they open in a new tab' do
      url = 'https://example.com/songs/123'

      link = Nokogiri::HTML.fragment(admin_url_value(url)).at_css('a')

      assert_equal url, link['href']
      assert_equal url, link.text
      assert_equal '_blank', link['target']
      assert_equal 'noopener', link['rel']
      assert_equal url, link['title']
      assert_equal "#{url}（新しいタブで開く）", link['aria-label']
    end

    test 'blank url values remain non-links' do
      assert_equal '-', admin_url_value('')
    end
  end
end

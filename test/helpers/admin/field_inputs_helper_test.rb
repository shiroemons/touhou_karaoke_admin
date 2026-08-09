require 'test_helper'

module Admin
  class FieldInputsHelperTest < ActionView::TestCase
    include FieldInputsHelper

    Field = Struct.new(:name, :label, :type, :options)

    test 'has many select preserves input attributes on its search field' do
      record = DisplayArtist.new
      field = Field.new(:circle_ids, 'サークル', :has_many_select, [['上海アリス幻樂団', 1]])
      input_options = {
        class: 'input-error',
        aria: { invalid: true, describedby: 'display_artist_circle_ids_error' },
        data: { test_marker: 'preserved' }
      }

      html = form_with model: record, url: '/admin/display_artists/1' do |form|
        admin_field_input(form, field, input_options)
      end

      search_input = Nokogiri::HTML.fragment(html).at_css('#admin_searchable_select_display_artist_circle_ids-search')

      assert search_input
      assert_includes search_input['class'].split, 'input-error'
      assert_equal 'true', search_input['aria-invalid']
      assert_equal 'preserved', search_input['data-test-marker']
      assert_includes search_input['aria-describedby'].split, 'admin_searchable_select_display_artist_circle_ids-status'
      assert_includes search_input['aria-describedby'].split, 'display_artist_circle_ids_error'
      assert_equal 'input-error', input_options[:class]
      assert_equal({ invalid: true, describedby: 'display_artist_circle_ids_error' }, input_options[:aria])
    end
  end
end

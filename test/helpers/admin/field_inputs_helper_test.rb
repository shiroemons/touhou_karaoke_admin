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

    test 'has many select error links target its searchable input' do
      record = DisplayArtist.new
      field = Field.new(:circle_ids, 'サークル', :has_many_select, [['上海アリス幻樂団', 1]])
      focus_id = nil

      form_with model: record, url: '/admin/display_artists/1' do |form|
        focus_id = admin_form_field_focus_id(form, field)
      end

      assert_equal 'admin_searchable_select_display_artist_circle_ids-search', focus_id
    end

    test 'regular field error links target the model field input' do
      record = DisplayArtist.new
      field = Field.new(:name, 'アーティスト名', :text, [])
      focus_id = nil

      form_with model: record, url: '/admin/display_artists/1' do |form|
        focus_id = admin_form_field_focus_id(form, field)
      end

      assert_equal 'display_artist_name', focus_id
    end
  end
end

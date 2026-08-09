require 'test_helper'

module Admin
  class IconsHelperTest < ActionView::TestCase
    test 'all icon aliases resolve to bundled Lucide SVGs' do
      missing_icons = IconsHelper::ICON_ALIASES.values.reject do |icon_name|
        IconsHelper::ICONS_PATH.join("#{icon_name}.svg").file?
      end

      assert_empty missing_icons, "Missing Lucide SVGs: #{missing_icons.join(', ')}"
    end
  end
end

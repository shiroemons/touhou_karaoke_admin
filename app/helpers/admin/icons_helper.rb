module Admin
  module IconsHelper
    ICONS_PATH = Rails.root.join('node_modules/lucide-static/icons')
    ICON_ALIASES = {
      dashboard: 'layout-dashboard',
      originals: 'book-open',
      original_songs: 'music',
      karaoke_delivery_models: 'radio',
      circles: 'disc-3',
      songs: 'mic-2',
      display_artists: 'users',
      dam_songs: 'music-2',
      dam_artist_urls: 'link',
      joysound_songs: 'audio-lines',
      joysound_music_posts: 'send',
      show: 'eye',
      edit: 'pencil',
      delete: 'trash-2',
      create: 'plus',
      search: 'search',
      filter: 'sliders-horizontal',
      clear: 'x',
      sort: 'arrow-up-down',
      sort_asc: 'arrow-up',
      sort_desc: 'arrow-down',
      back: 'arrow-left',
      next: 'arrow-right',
      disclosure: 'chevron-down',
      action: 'play',
      upload: 'upload',
      download: 'download',
      infinite: 'list-plus',
      paginated: 'panel-top'
    }.freeze
    ICON_TAGS = %w[svg path circle rect line polyline polygon].freeze
    ICON_ATTRIBUTES = %w[
      aria-hidden class cx cy d fill focusable height points r stroke stroke-linecap
      stroke-linejoin stroke-width viewBox width x x1 x2 y y1 y2 xmlns
    ].freeze

    def admin_icon(name, **options)
      icon_name = ICON_ALIASES.fetch(name.to_sym, name.to_s)
      path = ICONS_PATH.join("#{icon_name}.svg")
      return unless path.file?

      svg = path.read
      classes = ['admin-icon', options.delete(:class)].compact.join(' ')
      svg = svg.sub(/<svg\b[^>]*>/) do |tag|
        tag = if tag.include?('class="')
                tag.sub(/class="([^"]*)"/, %(class="\\1 #{classes}"))
              else
                tag.sub('<svg', %(<svg class="#{classes}"))
              end
        tag = tag.sub('<svg', '<svg aria-hidden="true" focusable="false"') unless tag.include?('aria-hidden=')
        tag
      end

      sanitize(
        svg,
        tags: ICON_TAGS,
        attributes: ICON_ATTRIBUTES
      )
    end

    def admin_resource_icon(resource)
      admin_icon(resource.route_name.to_sym)
    end
  end
end

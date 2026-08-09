module Admin
  module SortingHelper
    def admin_sort_link(resource, field)
      current_direction = admin_sort_direction(field)
      next_params = next_sort_params(field, current_direction)

      link_to admin_resources_path(resource, admin_index_params(next_params)),
              class: ['admin-sort-link', ('admin-sort-link-active' if current_direction.present?)],
              aria: { label: sort_link_aria_label(field, current_direction) } do
        safe_join([
                    content_tag(:span, field.label, class: 'admin-sort-label'),
                    admin_icon(sort_icon(current_direction), class: 'admin-sort-icon')
                  ])
      end
    end

    def admin_sort_order(field)
      { 'asc' => 'ascending', 'desc' => 'descending' }[admin_sort_direction(field)]
    end

    def admin_sort_direction(field)
      return unless params[:sort].to_s == field.name.to_s

      direction = params[:direction].to_s
      direction if %w[asc desc].include?(direction)
    end

    def next_sort_params(field, current_direction)
      base_params = { page: 1 }

      case current_direction
      when 'asc'
        base_params.merge(sort: field.name, direction: 'desc')
      when 'desc'
        base_params.merge(sort: nil, direction: nil)
      else
        base_params.merge(sort: field.name, direction: 'asc')
      end
    end

    def sort_icon(current_direction)
      case current_direction
      when 'asc'
        :sort_asc
      when 'desc'
        :sort_desc
      else
        :sort
      end
    end

    def sort_link_aria_label(field, current_direction)
      case current_direction
      when 'asc'
        "#{field.label}（昇順）。クリックで降順に変更"
      when 'desc'
        "#{field.label}（降順）。クリックで既定の並び順に戻す"
      else
        "#{field.label}。クリックで昇順に並べ替え"
      end
    end
  end
end

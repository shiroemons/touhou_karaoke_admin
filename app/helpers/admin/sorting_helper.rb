module Admin
  module SortingHelper
    def admin_sort_link(resource, field)
      current_direction = params[:sort].to_s == field.name.to_s ? params[:direction].to_s : nil
      next_params = next_sort_params(field, current_direction)

      link_to admin_resources_path(resource, admin_index_params(next_params)),
              class: ['admin-sort-link', ('admin-sort-link-active' if current_direction.present?)] do
        safe_join([
                    content_tag(:span, field.label, class: 'admin-sort-label'),
                    admin_icon(sort_icon(current_direction), class: 'admin-sort-icon')
                  ])
      end
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
  end
end

# frozen_string_literal: true

module Admin
  class ResourceIndexQuery
    def initialize(resource:, params:, scope:, per_page_options:)
      @resource = resource
      @params = params
      @scope = scope
      @per_page_options = per_page_options
    end

    def records
      ordered_scope.offset((page - 1) * per_page).limit(per_page)
    end

    def total_count
      @total_count ||= filtered_scope.count
    end

    def total_pages
      [(total_count.to_f / per_page).ceil, 1].max
    end

    def page
      requested_page = scalar_param(:page).to_i
      requested_page.positive? ? requested_page : 1
    end

    def per_page
      requested_per_page = scalar_param(:per_page).to_i
      @per_page_options.include?(requested_per_page) ? requested_per_page : @per_page_options.first
    end

    def view_mode
      params[:view_mode] == 'paginated' ? 'paginated' : 'infinite'
    end

    def active_filters
      raw_filters = params[:filters]
      return {} unless raw_filters

      raw_filters = raw_filters.to_unsafe_h if raw_filters.respond_to?(:to_unsafe_h)
      return {} unless raw_filters.is_a?(Hash)

      raw_filters.each_with_object({}) do |(name, value), result|
        sanitized_value = sanitized_filter_value(value)
        result[name.to_s] = sanitized_value if sanitized_value.present?
      end
    end

    def filtered_scope
      @filtered_scope ||= begin
        scoped = apply_includes(scope)
        scoped = apply_search(scoped)
        apply_filters(scoped)
      end
    end

    def ordered_scope
      apply_order(filtered_scope)
    end

    private

    attr_reader :resource, :params, :scope

    def model
      resource.model
    end

    def apply_includes(scoped)
      return scoped if resource.includes.blank?

      scoped.includes(*resource.includes)
    end

    def apply_search(scoped)
      query = scalar_param(:q).to_s.strip
      return scoped if query.blank?

      pattern = "%#{model.sanitize_sql_like(query)}%"
      search_parts = search_conditions(pattern)

      return scoped if search_parts[:conditions].blank?

      search_parts[:joins].reduce(scoped, &:left_outer_joins).where(search_parts[:conditions].reduce { |memo, condition| memo.or(condition) })
    end

    def search_conditions(pattern)
      resource.search.keys.each_with_object({ joins: [], conditions: [] }) do |key, result|
        column_path = key.to_s.delete_suffix('_cont')
        next if column_path == 'm'

        if model.column_names.include?(column_path)
          result[:conditions] << model.arel_table[column_path].matches(pattern)
          next
        end

        association, column = association_search_column(column_path)
        next unless association && column

        result[:joins] << association.name
        result[:conditions] << association.klass.arel_table[column].matches(pattern)
      end
    end

    def association_search_column(column_path)
      association = model.reflect_on_all_associations.find do |candidate|
        column_path.start_with?("#{candidate.name}_")
      end
      return [nil, nil] unless association

      column = column_path.delete_prefix("#{association.name}_")
      association.klass.column_names.include?(column) ? [association, column] : [nil, nil]
    end

    def apply_filters(scoped)
      return scoped if resource.filters.blank?

      active_filters.reduce(scoped) do |filtered_scope, (name, value)|
        filter = resource.filter_by_name(name)
        next filtered_scope unless filter

        if filter.type == :presence_groups
          next filtered_scope unless valid_presence_group_filter?(filter, value)

          next filter.apply.call(filtered_scope, value)
        end

        values = Array(value)
        next filtered_scope if values.blank?
        next filtered_scope unless values.all? { |item| filter.options.keys.map(&:to_s).include?(item) }

        filter.apply.call(filtered_scope, filter.type == :checkboxes ? values : values.first)
      end
    end

    def sanitized_filter_value(value)
      if value.is_a?(Array)
        value.map(&:to_s).filter_map(&:presence)
      elsif value.is_a?(Hash)
        value.each_with_object({}) do |(key, item), result|
          sanitized_item = item.to_s.presence
          result[key.to_s] = sanitized_item if sanitized_item
        end
      else
        value.to_s.presence
      end
    end

    def valid_presence_group_filter?(filter, value)
      return false unless value.is_a?(Hash) && value.present?

      valid_keys = filter.options.keys.map(&:to_s)
      valid_values = %w[present missing]
      value.all? do |key, item|
        valid_keys.include?(key.to_s) && valid_values.include?(item.to_s)
      end
    end

    def apply_order(scoped)
      sort_field = resource.fields.find { |field| field.sortable && field.name.to_s == scalar_param(:sort).to_s }
      direction = params[:direction] == 'asc' ? :asc : :desc

      if sort_field && model.column_names.include?(sort_field.name.to_s)
        scoped.reorder(sort_field.name => direction)
      elsif sort_field&.count_association
        apply_count_order(scoped, sort_field, direction)
      elsif sort_field&.type == :belongs_to
        apply_association_order(scoped, sort_field, direction)
      elsif resource.order.present?
        scoped.order(resource.order)
      else
        scoped
      end
    end

    def apply_association_order(scoped, field, direction)
      association = model.reflect_on_association(field.name)
      return scoped unless association

      sort_column = association_sort_column(association.klass)
      return scoped unless sort_column

      scoped.left_outer_joins(field.name).reorder(association.klass.arel_table[sort_column].public_send(direction))
    end

    def apply_count_order(scoped, field, direction)
      association = model.reflect_on_association(field.count_association)
      return scoped unless association

      quoted_table = association.klass.quoted_table_name
      quoted_primary_key = association.klass.connection.quote_column_name(association.klass.primary_key)
      count_expression = "COUNT(DISTINCT #{quoted_table}.#{quoted_primary_key}) #{direction.to_s.upcase}"

      scoped
        .left_outer_joins(field.count_association)
        .group("#{model.quoted_table_name}.#{model.connection.quote_column_name(model.primary_key)}")
        .reorder(Arel.sql(count_expression))
    end

    def association_sort_column(klass)
      associated_resource = ResourceRegistry.all.values.find { |item| item.model == klass }
      resource_title = associated_resource&.title
      candidates = [resource_title.respond_to?(:call) ? nil : resource_title, :name, :title, :display_title, :url, :code, :id].compact.map(&:to_s)
      candidates.find { |column| klass.column_names.include?(column) }
    end

    def scalar_param(key)
      value = params[key]
      return nil if value.is_a?(Array) || value.is_a?(Hash) || value.is_a?(ActionController::Parameters)

      value
    end
  end
end

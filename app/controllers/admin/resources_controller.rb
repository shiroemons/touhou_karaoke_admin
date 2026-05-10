module Admin
  class ResourcesController < BaseController
    PER_PAGE_OPTIONS = [24, 48, 72, 100].freeze
    class_attribute :resource_key

    helper_method :admin_recent_change_logs

    before_action :set_resource
    before_action :set_record, only: %i[show edit update destroy operation operation_progress]

    def index
      authorize model
      scope = policy_scope(model)
      scope = apply_includes(scope)
      scope = apply_search(scope)
      scope = apply_filters(scope)
      @active_filters = active_filter_params
      @page = requested_page
      @per_page = requested_per_page
      @view_mode = requested_view_mode
      @total_count = scope.count
      scope = apply_order(scope)
      @total_pages = [(@total_count.to_f / @per_page).ceil, 1].max
      @records = scope.offset((@page - 1) * @per_page).limit(@per_page)
      load_recent_change_logs

      if infinite_scroll_rows_request?
        render json: {
          html: render_to_string(partial: 'admin/resources/rows', formats: [:html], layout: false),
          next_url: next_infinite_scroll_url
        }
        return
      end

      @next_infinite_scroll_url = next_infinite_scroll_url
      if async_index_request?
        render json: {
          html: render_to_string(template: 'admin/resources/index', formats: [:html], layout: false)
        }
        return
      end

      render 'admin/resources/index'
    end

    def show
      authorize @record
      @change_logs = ChangeLog.recent_for_record(@resource.key.to_s, @record)
      render 'admin/resources/show'
    end

    def new
      @record = model.new
      authorize @record
      render 'admin/resources/new'
    end

    def edit
      authorize @record
      render 'admin/resources/edit'
    end

    def create
      @record = model.new(resource_params)
      authorize @record

      if @record.save
        ChangeLog.record_create!(resource: @resource, record: @record, actor_name: current_user.name)
        redirect_to admin_resource_path(@resource, @record), notice: I18n.t('admin.created', resource: @resource.label)
      else
        render 'admin/resources/new', status: :unprocessable_content
      end
    end

    def update
      authorize @record

      if @record.update(resource_params)
        ChangeLog.record_update!(resource: @resource, record: @record, actor_name: current_user.name)
        redirect_to admin_resource_path(@resource, @record), notice: I18n.t('admin.updated', resource: @resource.label)
      else
        render 'admin/resources/edit', status: :unprocessable_content
      end
    end

    def destroy
      authorize @record
      @record.destroy!
      ChangeLog.record_destroy!(resource: @resource, record: @record, actor_name: current_user.name)
      redirect_to admin_resources_path(@resource), notice: I18n.t('admin.destroyed', resource: @resource.label)
    end

    def operation
      @operation = find_operation
      authorize_operation!

      if request.get? || request.head?
        render 'admin/resources/operation'
        return
      end

      result = OperationRunner.new(resource: @resource, operation: @operation, record: @record, params:, scope: operation_scope).run

      if result.download_data.present?
        send_data result.download_data,
                  filename: result.download_filename,
                  type: result.download_content_type,
                  disposition: :attachment
        return
      end

      redirect_back_or_to admin_resources_path(@resource), notice: result.message
    rescue ArgumentError => e
      redirect_back_or_to admin_resources_path(@resource), alert: e.message
    rescue StandardError => e
      Rails.logger.error(e)
      redirect_back_or_to admin_resources_path(@resource), alert: "処理中にエラーが発生しました。#{e.message}"
    end

    def operation_progress
      @operation = find_operation
      authorize_operation!

      render json: OperationProgress.read(params[:operation_progress_id])
    end

    private

    def set_resource
      @resource = ResourceRegistry.fetch(resource_key || params[:resource])
    end

    def model
      @resource.model
    end

    def set_record
      @record = model.find(params[:id]) if params[:id].present?
    end

    def resource_params
      params.expect(@resource.param_key => @resource.strong_parameters)
    end

    def apply_includes(scope)
      return scope if @resource.includes.blank?

      scope.includes(*@resource.includes)
    end

    def apply_search(scope)
      query = params[:q].to_s.strip
      return scope if query.blank?

      pattern = "%#{model.sanitize_sql_like(query)}%"
      search_parts = search_conditions(pattern)

      return scope if search_parts[:conditions].blank?

      search_parts[:joins].reduce(scope, &:left_outer_joins).where(search_parts[:conditions].reduce { |memo, condition| memo.or(condition) })
    end

    def search_conditions(pattern)
      @resource.search.keys.each_with_object({ joins: [], conditions: [] }) do |key, result|
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

    def apply_filters(scope)
      return scope if @resource.filters.blank?

      active_filter_params.reduce(scope) do |filtered_scope, (name, value)|
        filter = @resource.filter_by_name(name)
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

    def active_filter_params
      raw_filters = params[:filters]
      return {} unless raw_filters

      raw_filters = raw_filters.to_unsafe_h if raw_filters.respond_to?(:to_unsafe_h)
      return {} unless raw_filters.is_a?(Hash)

      raw_filters.each_with_object({}) do |(name, value), result|
        sanitized_value = sanitized_filter_value(value)
        result[name.to_s] = sanitized_value if sanitized_value.present?
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

    def apply_order(scope)
      sort_field = @resource.fields.find { |field| field.sortable && field.name.to_s == params[:sort].to_s }
      direction = params[:direction] == 'asc' ? :asc : :desc

      if sort_field && model.column_names.include?(sort_field.name.to_s)
        scope.reorder(sort_field.name => direction)
      elsif sort_field&.count_association
        apply_count_order(scope, sort_field, direction)
      elsif sort_field&.type == :belongs_to
        apply_association_order(scope, sort_field, direction)
      elsif @resource.order.present?
        scope.order(@resource.order)
      else
        scope
      end
    end

    def apply_association_order(scope, field, direction)
      association = model.reflect_on_association(field.name)
      return scope unless association

      sort_column = association_sort_column(association.klass)
      return scope unless sort_column

      scope.left_outer_joins(field.name).reorder(association.klass.arel_table[sort_column].public_send(direction))
    end

    def apply_count_order(scope, field, direction)
      association = model.reflect_on_association(field.count_association)
      return scope unless association

      quoted_table = association.klass.quoted_table_name
      quoted_primary_key = association.klass.connection.quote_column_name(association.klass.primary_key)
      count_expression = "COUNT(DISTINCT #{quoted_table}.#{quoted_primary_key}) #{direction.to_s.upcase}"

      scope
        .left_outer_joins(field.count_association)
        .group("#{model.quoted_table_name}.#{model.connection.quote_column_name(model.primary_key)}")
        .reorder(Arel.sql(count_expression))
    end

    def association_sort_column(klass)
      resource = ResourceRegistry.all.values.find { |item| item.model == klass }
      resource_title = resource&.title
      candidates = [resource_title.respond_to?(:call) ? nil : resource_title, :name, :title, :display_title, :url, :code, :id].compact.map(&:to_s)
      candidates.find { |column| klass.column_names.include?(column) }
    end

    def requested_page
      page = params[:page].to_i
      page.positive? ? page : 1
    end

    def requested_per_page
      per_page = params[:per_page].to_i
      PER_PAGE_OPTIONS.include?(per_page) ? per_page : PER_PAGE_OPTIONS.first
    end

    def requested_view_mode
      params[:view_mode] == 'paginated' ? 'paginated' : 'infinite'
    end

    def load_recent_change_logs
      @recent_admin_change_logs = ChangeLog.latest_for_records(@resource.key.to_s, @records)
    end

    def admin_recent_change_logs
      @recent_admin_change_logs || {}
    end

    def infinite_scroll_rows_request?
      params[:partial] == 'rows' && @view_mode == 'infinite'
    end

    def async_index_request?
      params[:partial] == 'content'
    end

    def next_infinite_scroll_url
      return nil unless @view_mode == 'infinite' && @page < @total_pages

      admin_resources_path(@resource, request.query_parameters.merge(page: @page + 1, view_mode: 'infinite', partial: 'rows'))
    end

    def find_operation
      operation_identifier = params[:operation].to_s
      return @resource.operations.fetch(operation_identifier.to_i) if operation_identifier.match?(/\A\d+\z/)

      @resource.operations.find { |operation| operation.key == operation_identifier || operation.avo_action == operation_identifier } ||
        raise(ArgumentError, '指定されたアクションは見つかりません。')
    end

    def operation_scope
      scope = policy_scope(model)
      scope = apply_includes(scope)
      scope = apply_search(scope)
      scope = apply_filters(scope)
      apply_order(scope)
    end

    def authorize_operation!
      policy = policy(@record || model)
      allowed = if policy.respond_to?(:act_on?)
                  policy.act_on?
                elsif policy.respond_to?(:reorder?)
                  policy.reorder?
                else
                  false
                end
      raise Pundit::NotAuthorizedError unless allowed
    end
  end
end

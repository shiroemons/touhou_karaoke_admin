module Admin
  class ResourcesController < BaseController
    PER_PAGE_OPTIONS = [24, 48, 72, 100].freeze
    class_attribute :resource_key

    helper_method :admin_cached_association_count, :admin_recent_change_logs

    before_action :set_resource
    before_action :set_record, only: %i[show edit update destroy operation operation_progress]

    def index
      authorize model
      query = resource_index_query(policy_scope(model))
      @active_filters = query.active_filters
      @page = query.page
      @per_page = query.per_page
      @view_mode = query.view_mode
      @total_count = query.total_count
      @total_pages = query.total_pages
      @records = query.records
      load_index_association_counts
      load_recent_change_logs

      @next_infinite_scroll_url = next_infinite_scroll_url
      return if resource_index_responder.call

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

      if @operation.async
        progress_id = operation_progress_id
        message = "#{@operation.label}のバックグラウンド処理を開始しました。"
        OperationProgress.enqueue!(progress_id, label: "#{@operation.label}を開始待ちです")
        OperationJob.perform_later(
          resource_key: @resource.key.to_s,
          operation_key: @operation.key,
          record_id: @record&.id,
          actor_name: current_user.name,
          params: operation_job_params(progress_id)
        )

        respond_to do |format|
          format.json do
            render json: {
              message:,
              progress: OperationProgress.read(progress_id)
            }, status: :accepted
          end
          format.html do
            redirect_back_or_to admin_resources_path(@resource), notice: message
          end
        end
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
    rescue OperationRunner::InputError, ArgumentError => e
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
      id = scalar_param(:id)
      @record = record_lookup_scope.find(id) if id.present?
    end

    def record_lookup_scope
      return model unless action_name == 'show'

      apply_includes(model)
    end

    def resource_params
      params.expect(@resource.param_key => @resource.strong_parameters)
    end

    def apply_includes(scope)
      return scope if @resource.includes.blank?

      scope.includes(*@resource.includes)
    end

    def load_recent_change_logs
      @recent_admin_change_logs = ChangeLog.latest_for_records(@resource.key.to_s, @records)
    end

    def load_index_association_counts
      count_associations = @resource.index_fields.filter_map(&:count_association).uniq
      return if count_associations.blank? || @records.blank?

      @association_counts = count_associations.index_with do |association|
        association_counts_for(association)
      end
    end

    def association_counts_for(association)
      record_ids = @records.map(&:id)
      zero_counts = record_ids.index_with { 0 }

      counts = case [model.name, association.to_sym]
               when ['Circle', :display_artists]
                 DisplayArtistsCircle.where(circle_id: record_ids).group(:circle_id).count
               when ['Circle', :songs]
                 circle_song_counts(record_ids)
               else
                 @records.index_with { |record| record.public_send(association).size }
               end

      zero_counts.merge(counts)
    end

    def circle_song_counts(circle_ids)
      Song
        .joins(display_artist: :display_artists_circles)
        .where(display_artists_circles: { circle_id: circle_ids })
        .group('display_artists_circles.circle_id')
        .distinct
        .count(:id)
    end

    def admin_recent_change_logs
      @recent_admin_change_logs || {}
    end

    def admin_cached_association_count(record, association)
      association_counts = (@association_counts ||= {})
      counts = (association_counts[association.to_sym] ||= {})
      return counts[record.id] if counts.key?(record.id)

      counts[record.id] = record.public_send(association).size
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

    def resource_index_responder
      ResourceIndexResponder.new(
        controller: self,
        rows_request: infinite_scroll_rows_request?,
        content_request: async_index_request?,
        next_url: @next_infinite_scroll_url
      )
    end

    def find_operation
      operation_identifier = scalar_param(:operation).to_s
      return @resource.operations.fetch(operation_identifier.to_i) if operation_identifier.match?(/\A\d+\z/)

      @resource.operations.find { |operation| operation.key == operation_identifier || operation.action_key == operation_identifier } ||
        raise(ArgumentError, '指定されたアクションは見つかりません。')
    end

    def scalar_param(key)
      value = params[key]
      return nil if value.is_a?(Array) || value.is_a?(Hash) || value.is_a?(ActionController::Parameters)

      value
    end

    def operation_progress_id
      id = scalar_param(:operation_progress_id)
      OperationProgress.valid_id?(id) ? id : SecureRandom.uuid
    end

    def operation_job_params(progress_id)
      permitted = params.permit(:operation, :operation_progress_id, selected_ids: [], operation_fields: operation_field_param_keys)
      permitted.to_h.merge('operation_progress_id' => progress_id)
    end

    def operation_field_param_keys
      @operation.inputs.reject { |input| input[:type] == :file }.pluck(:name)
    end

    def operation_scope
      resource_index_query(policy_scope(model)).ordered_scope
    end

    def resource_index_query(scope)
      ResourceIndexQuery.new(resource: @resource, params:, scope:, per_page_options: PER_PAGE_OPTIONS)
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

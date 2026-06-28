# frozen_string_literal: true

module Admin
  Field = Data.define(:name, :label, :type, :index, :show, :form, :readonly, :sortable, :options, :link, :helper, :count_association)
  Filter = Data.define(:name, :label, :type, :options, :apply)
  Operation = Data.define(
    :key,
    :action_key,
    :label,
    :description,
    :method_name,
    :confirmation,
    :scope,
    :handler,
    :inputs,
    :group,
    :estimated_seconds,
    :selection,
    :async,
    :repeat_while_created,
    :max_attempts
  )

  Resource = Data.define(
    :key,
    :model,
    :label,
    :title,
    :navigation,
    :includes,
    :order,
    :search,
    :filters,
    :fields,
    :associations,
    :operations,
    :strong_parameters
  ) do
    def controller_name
      key.to_s.pluralize
    end

    def route_name
      key.to_s.pluralize
    end

    def param_key
      key
    end

    def index_fields
      fields.select(&:index)
    end

    def show_fields
      fields.select(&:show)
    end

    def form_fields
      fields.select { |field| field.form && !field.readonly }
    end

    def filter_by_name(name)
      filters.find { |filter| filter.name.to_s == name.to_s }
    end
  end

  class ResourceRegistry
    FULL_JOYSOUND_MUSIC_POST_MAINTENANCE_DESCRIPTION = OperationDescriptions::FULL_JOYSOUND_MUSIC_POST_MAINTENANCE
    FETCH_JOYSOUND_TOUHOU_SONGS_DESCRIPTION = OperationDescriptions::FETCH_JOYSOUND_TOUHOU_SONGS
    OPERATION_DESCRIPTIONS = OperationDescriptions::ALL

    NAVIGATION_GROUPS = {
      '作品マスタ' => %i[original original_song],
      '配信管理' => %i[circle display_artist song karaoke_delivery_model],
      'DAM' => %i[dam_song dam_artist_url],
      'JOYSOUND' => %i[joysound_song joysound_music_post]
    }.freeze

    class << self
      include ResourceRegistryDefinitions

      def all
        @all ||= build_resources.index_by(&:key)
      end

      def fetch(key)
        all.fetch(key.to_sym)
      end

      def navigable
        all.values.select(&:navigation)
      end

      def navigation_groups
        resources = navigable.index_by(&:key)
        groups = NAVIGATION_GROUPS.filter_map do |label, keys|
          grouped_resources = keys.filter_map { |key| resources.delete(key) }
          [label, grouped_resources] if grouped_resources.present?
        end
        groups << ['その他', resources.values] if resources.present?
        groups
      end
    end
  end
end

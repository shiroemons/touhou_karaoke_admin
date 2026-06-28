module Admin
  class OperationChangeSummary
    NO_CHANGES_MESSAGE = '変更なし（追加・更新・削除はありません）'.freeze

    def initialize(resources: ResourceRegistry.all.values)
      @resources = resources
    end

    def snapshot
      tracked_change_models.to_h { |model| [model.name, model.count] }
    end

    def summarize(baseline:, started_at:)
      summaries = change_summaries(baseline:, started_at:).filter_map { |summary| summary[:text] }

      return NO_CHANGES_MESSAGE if summaries.blank?

      "DB変更: #{summaries.join('、')}"
    end

    def metadata(baseline:, started_at:)
      summaries = change_summaries(baseline:, started_at:)

      {
        created_count: summaries.sum { |summary| summary[:created_count] },
        updated_count: summaries.sum { |summary| summary[:updated_count] },
        deleted_count: summaries.sum { |summary| summary[:deleted_count] },
        resources: summaries
      }
    end

    private

    attr_reader :resources

    def change_summaries(baseline:, started_at:)
      tracked_change_models.map do |model|
        summarize_model_changes(model, baseline.fetch(model.name, 0), started_at)
      end
    end

    def summarize_model_changes(model, before_count, started_at)
      after_count = model.count
      created_count = timestamp_count(model, :created_at, started_at)
      updated_count = updated_existing_count(model, started_at)
      deleted_count = [before_count + created_count - after_count, 0].max
      parts = []
      parts << "追加#{created_count}件" if created_count.positive?
      parts << "更新#{updated_count}件" if updated_count.positive?
      parts << "削除#{deleted_count}件" if deleted_count.positive?

      {
        model: model.name,
        label: change_model_label(model),
        created_count:,
        updated_count:,
        deleted_count:,
        text: parts.present? ? "#{change_model_label(model)} #{parts.join(' ')}" : nil
      }
    end

    def timestamp_count(model, column, started_at)
      return 0 unless model.column_names.include?(column.to_s)

      model.where(column => started_at..).count
    end

    def updated_existing_count(model, started_at)
      return 0 unless model.column_names.include?('updated_at')
      return timestamp_count(model, :updated_at, started_at) unless model.column_names.include?('created_at')

      model.where(updated_at: started_at..).where(model.arel_table[:created_at].lt(started_at)).count
    end

    def tracked_change_models
      @tracked_change_models ||= resources.map(&:model).uniq.select do |model|
        model.table_exists? && model.column_names.intersect?(%w[created_at updated_at])
      end
    end

    def change_model_label(model)
      change_model_labels.fetch(model.name, model.model_name.human)
    end

    def change_model_labels
      @change_model_labels ||= resources.to_h { |resource| [resource.model.name, resource.label] }
    end
  end
end

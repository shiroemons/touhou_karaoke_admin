# frozen_string_literal: true

require "json"

# Algolia record comparison helpers used by maintenance scripts.
module AlgoliaRecordComparator
  URL_DELETION_WARNING_FIELDS = %w[
    url
    ouchikaraoke_url
    musicpost_url
    display_artist.url
  ].freeze

  module_function

  def deep_diff(old_value, new_value, path = "")
    differences = []

    case new_value
    when Hash
      differences.concat(diff_hash(old_value, new_value, path))
    when Array
      differences << { path: path, old: old_value, new: new_value } if array_changed?(old_value, new_value)
    else
      differences << { path: path, old: old_value, new: new_value } if old_value != new_value
    end

    differences
  end

  def diff_hash(old_value, new_value, path)
    return [{ path: path, old: old_value, new: new_value }] unless old_value.is_a?(Hash)

    all_keys = (old_value.keys + new_value.keys).map(&:to_s).uniq
    all_keys.flat_map do |key|
      new_path = path.empty? ? key : "#{path}.#{key}"
      old_val = old_value[key] || old_value[key.to_sym]
      new_val = new_value[key] || new_value[key.to_sym]
      deep_diff(old_val, new_val, new_path)
    end
  end

  def array_changed?(old_value, new_value)
    normalize_array(old_value).to_json != normalize_array(new_value).to_json
  end

  def normalize_value(value)
    case value
    when Hash
      value.transform_keys(&:to_s).sort.to_h.transform_values { |v| normalize_value(v) }
    when Array
      normalize_array(value)
    else
      value
    end
  end

  def normalize_array(arr)
    return arr unless arr.is_a?(Array)

    arr.map { |item| normalize_value(item) }.sort_by(&:to_json)
  end

  def detect_url_deletions(differences)
    differences.select do |diff|
      URL_DELETION_WARNING_FIELDS.include?(diff[:path]) && !diff[:old].nil? && diff[:new].nil?
    end
  end
end

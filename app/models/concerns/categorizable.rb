module Categorizable
  extend ActiveSupport::Concern

  ORIGINAL_TYPE = {
    windows: "01. Windows作品",
    pc98: "02. PC-98作品",
    zuns_music_collection: "03. ZUN's Music Collection",
    akyus_untouched_score: "04. 幺樂団の歴史　～ Akyu's Untouched Score",
    commercial_books: "05. 商業書籍",
    other: "06. その他"
  }.freeze

  def first_category(original)
    ORIGINAL_TYPE[original.original_type.to_sym]
  end

  def second_category(original)
    "#{first_category(original)} > #{format('%#04.1f', original.series_order)}. #{original.short_title}"
  end

  def third_category(original_song)
    original = original_song.original
    "#{second_category(original)} > #{format('%02d', original_song.track_number)}. #{original_song.title}"
  end
end

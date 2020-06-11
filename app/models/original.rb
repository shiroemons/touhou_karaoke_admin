class Original < ApplicationRecord
  enum original_type: {
    pc98: 'pc98',
    windows: 'windows',
    zuns_music_collection: 'zuns_music_collection',
    akyus_untouched_score: 'akyus_untouched_score',
    commercial_books: 'commercial_books',
    other: 'other',
  }
end

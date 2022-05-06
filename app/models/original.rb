class Original < ApplicationRecord
  enum original_type: {
    pc98: 'pc98',
    windows: 'windows',
    zuns_music_collection: 'zuns_music_collection',
    akyus_untouched_score: 'akyus_untouched_score',
    commercial_books: 'commercial_books',
    other: 'other',
  }

  has_many :original_songs, -> { order(Arel.sql('"original_songs"."track_number" ASC')) },
           foreign_key: :original_code,
           primary_key: :code,
           inverse_of: :original,
           dependent: :destroy
end

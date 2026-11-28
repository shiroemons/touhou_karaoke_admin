# frozen_string_literal: true

class JoysoundMusicPostPrioritizer
  def self.call
    new.call
  end

  def call
    (unmatched_posts.to_a + upcoming_posts.to_a).uniq
  end

  private

  def unmatched_posts
    matched_song_exists = Song.music_post
                              .where(Song.arel_table[:url].eq(JoysoundMusicPost.arel_table[:joysound_url]))
                              .arel.exists

    JoysoundMusicPost.where.not(matched_song_exists)
  end

  # 期限切れと、管理画面の「残り30日以内」に入るもの。区切りは Admin::DeliveryDeadlineWindows と揃える
  def upcoming_posts
    JoysoundMusicPost
      .where(delivery_deadline_on: ..Admin::DeliveryDeadlineWindows.soon_until)
      .order(delivery_deadline_on: :asc)
  end
end

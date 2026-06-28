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
    unmatched_urls = JoysoundMusicPost.pluck(:joysound_url) - Song.music_post.pluck(:url)

    JoysoundMusicPost.where(joysound_url: unmatched_urls)
  end

  def upcoming_posts
    JoysoundMusicPost
      .where(delivery_deadline_on: ...1.month.from_now)
      .order(delivery_deadline_on: :asc)
  end
end

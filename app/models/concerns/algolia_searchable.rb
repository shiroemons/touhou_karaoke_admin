module AlgoliaSearchable
  extend ActiveSupport::Concern

  included do
    include AlgoliaSearch

    algoliasearch index_name: ENV.fetch('ALGOLIA_INDEX_NAME', nil), unless: :deleted? do
      attribute :title
      attribute :reading_title do
        title_reading || ''
      end
      attribute :display_artist do
        {
          name: display_artist.name,
          reading_name: display_artist.name_reading,
          reading_name_hiragana: display_artist.name_reading.tr('ァ-ン', 'ぁ-ん'),
          karaoke_type: display_artist.karaoke_type,
          url: display_artist.url
        }
      end
      attribute :original_songs do
        original_songs_json(original_songs)
      end
      attribute :karaoke_type
      attribute :karaoke_delivery_models do
        karaoke_delivery_models_json
      end
      attribute :circle do
        {
          name: display_artist.circles.first&.name || ''
        }
      end
      attribute :url
      attribute :song_number do
        song_number.presence
      end
      attribute :delivery_deadline_date do
        song_with_joysound_utasuki&.delivery_deadline_date&.strftime("%Y/%m/%d")
      end
      attribute :musicpost_url do
        song_with_joysound_utasuki&.url
      end
      attribute :ouchikaraoke_url do
        song_with_dam_ouchikaraoke&.url
      end
      attribute :videos
    end
  end

  def original_songs_json(original_songs)
    original_songs.map do |os|
      {
        title: os.title,
        original: {
          title: os.original.title,
          short_title: os.original.short_title
        },
        'categories.lvl0': first_category(os.original),
        'categories.lvl1': second_category(os.original),
        'categories.lvl2': third_category(os)
      }
    end
  end

  def karaoke_delivery_models_json
    karaoke_delivery_models.map do |kdm|
      {
        name: kdm.name,
        karaoke_type: kdm.karaoke_type
      }
    end
  end

  def videos
    v = []
    if youtube_url.present?
      m = /(?<=\?v=)(?<id>[\w\-_]+)(?!=&)/.match(youtube_url)
      v.push({ type: "YouTube", url: youtube_url, id: m[:id] })
    end
    if nicovideo_url.present?
      m = %r{(?<=watch/)(?<id>[s|n]m\d+)(?!=&)}.match(nicovideo_url)
      v.push({ type: "ニコニコ動画", url: nicovideo_url, id: m[:id] })
    end
    v
  end

  def deleted?
    return true if original_songs.blank?

    original_song_titles = original_songs.map(&:title)
    original_song_titles.include?("オリジナル") || original_song_titles.include?("その他")
  end
end
class DisplayArtist < ApplicationRecord
  has_many :display_artists_circles
  has_many :circles, through: :display_artists_circles
  has_many :songs, dependent: :destroy

  scope :dam, -> { where(karaoke_type: "DAM") }
  scope :joysound, -> { where(karaoke_type: "JOYSOUND") }
  scope :music_post, -> { where(karaoke_type: "JOYSOUND(うたスキ)") }
  scope :name_reading_empty, -> { where(name_reading: "") }

  def self.fetch_joysound_artist
    browser = Ferrum::Browser.new(timeout: 30, window_size: [1440, 900])
    total_count = DisplayArtist.joysound.name_reading_empty.count
    DisplayArtist.joysound.name_reading_empty.each.with_index(1) do |da, i|
      logger.debug("#{i}/#{total_count}: #{((i/total_count.to_f)*100).floor}%")
      browser.goto(da.url)

      artist_selector = "#jp-cmp-main > section:nth-child(2) > header > div.jp-cmp-h1-003-title > h1 > span"
      artist_el = browser.at_css(artist_selector)
      name_reading = artist_el.inner_text.gsub(/[（）]/, "")
      if name_reading.present?
        logger.debug(name_reading)
        da.name_reading = name_reading
        da.save!
      end
    end
  end

  def self.fetch_joysound_music_post_artist
    base_url = "https://www.joysound.com/web/search/artist?match=1&keyword="
    browser = Ferrum::Browser.new(timeout: 30, window_size: [1440, 2000])

    artists = JoysoundMusicPost.pluck(:artist).uniq.sort
    error_artist = []

    artists.each do |artist|
      rescue_count = 0
      begin
        url = base_url + CGI.escape(artist)
        browser.goto(url)

        result_list_selector = "#searchresult > ul > li"
        browser.css(result_list_selector).each do |el|
          no_data = el.inner_text
          if no_data == "該当データがありません"
            JoysoundMusicPost.where(artist: artist)&.destroy_all
            DisplayArtist.find_by(name: artist, karaoke_type: "JOYSOUND(うたスキ)")&.destory
          else
            next if DisplayArtist.exists?(name: artist, karaoke_type: "JOYSOUND(うたスキ)")

            option = el.at_css("div > div > div.jp-cmp-list-inline-003").inner_text
            option.gsub!("ウィキペディア", "")
            if option.blank?
              display_artist = el.at_css("h3.jp-cmp-music-title-001").inner_text
              display_artist.gsub!(" 新曲あり", "")
              if artist == display_artist
                el.at_css("a").focus.click
                artist_selector = "#jp-cmp-main > section:nth-child(2) > header > div.jp-cmp-h1-003-title > h1 > span"
                artist_el = browser.at_css(artist_selector)
                name_reading = artist_el.inner_text.gsub(/[（）]/, "")

                DisplayArtist.find_or_create_by!(name: display_artist, name_reading: name_reading, karaoke_type: "JOYSOUND(うたスキ)", url: browser.current_url)
              end
            end
          end
        end
      rescue Ferrum::NodeNotFoundError => e
        logger.debug(e)
        rescue_count += 1
        if rescue_count > 3
          browser.screenshot(path: "tmp/music_post_#{artist.gsub("/", "／")}.png")
          error_artist << artist
        else
          retry
        end
      end
    end
    logger.debug("未登録アーティスト：" + error_artist) if error_artist.present?
  end
end

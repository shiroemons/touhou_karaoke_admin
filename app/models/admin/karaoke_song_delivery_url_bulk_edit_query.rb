# frozen_string_literal: true

module Admin
  class KaraokeSongDeliveryUrlBulkEditQuery
    PER_PAGE = 100
    SORT_OPTIONS = {
      'created_at' => 'songs.created_at',
      'display_artist_name' => 'display_artists.name',
      'title' => 'songs.title',
      'karaoke_type' => 'songs.karaoke_type',
      'youtube_url' => 'songs.youtube_url',
      'nicovideo_url' => 'songs.nicovideo_url',
      'apple_music_url' => 'songs.apple_music_url',
      'youtube_music_url' => 'songs.youtube_music_url',
      'spotify_url' => 'songs.spotify_url',
      'line_music_url' => 'songs.line_music_url'
    }.freeze
    SORT_DIRECTION_OPTIONS = %w[asc desc].freeze

    def initialize(scope:, params:, karaoke_type_options:)
      @scope = scope
      @params = params
      @karaoke_type_options = karaoke_type_options
    end

    def query
      scalar_param(:q).to_s.strip
    end

    def missing_url_columns
      Array.wrap(params[:missing_url_columns]).select do |column|
        KaraokeSongDeliveryUrlBulkEditor::URL_COLUMNS.include?(column)
      end
    end

    def karaoke_type
      requested = scalar_param(:karaoke_type).to_s
      karaoke_type_options.include?(requested) ? requested : nil
    end

    def sort
      SORT_OPTIONS.key?(scalar_param(:sort).to_s) ? scalar_param(:sort).to_s : 'created_at'
    end

    def direction
      SORT_DIRECTION_OPTIONS.include?(scalar_param(:direction).to_s) ? scalar_param(:direction).to_s : 'desc'
    end

    def page
      requested_page = scalar_param(:page).to_i
      requested_page.positive? ? requested_page : 1
    end

    def per_page
      PER_PAGE
    end

    def total_count
      @total_count ||= filtered_scope.except(:order).count
    end

    def total_pages
      [(total_count.to_f / per_page).ceil, 1].max
    end

    def songs
      filtered_scope.offset((page - 1) * per_page).limit(per_page)
    end

    def index_params
      {
        q: query.presence,
        missing_url_columns: missing_url_columns.presence,
        karaoke_type: karaoke_type.presence,
        sort: scalar_param(:sort).present? ? sort : nil,
        direction: scalar_param(:direction).present? ? direction : nil,
        page: scalar_param(:page).presence
      }.compact
    end

    private

    attr_reader :scope, :params, :karaoke_type_options

    def filtered_scope
      @filtered_scope ||= begin
        scoped = scope.includes(:display_artist, original_songs: :original).left_outer_joins(:display_artist)
        scoped = apply_query(scoped)
        scoped = apply_missing_url_filters(scoped)
        scoped = apply_karaoke_type_filter(scoped)
        apply_order(scoped)
      end
    end

    def apply_query(scoped)
      return scoped if query.blank?

      pattern = "%#{Song.sanitize_sql_like(query)}%"
      songs = Song.arel_table
      artists = DisplayArtist.arel_table
      scoped.where(
        songs[:title].matches(pattern)
          .or(songs[:song_number].matches(pattern))
          .or(songs[:url].matches(pattern))
          .or(artists[:name].matches(pattern))
      )
    end

    def apply_missing_url_filters(scoped)
      missing_url_columns.reduce(scoped) do |filtered_scope, column|
        songs = Song.arel_table
        filtered_scope.where(songs[column].eq('').or(songs[column].eq(nil)))
      end
    end

    def apply_karaoke_type_filter(scoped)
      return scoped if karaoke_type.blank?

      scoped.where(karaoke_type:)
    end

    def apply_order(scoped)
      sort_expression = SORT_OPTIONS.fetch(sort)
      scoped.reorder(Arel.sql("#{sort_expression} #{direction.upcase}"), title: :asc)
    end

    def scalar_param(key)
      value = params[key]
      return nil if value.is_a?(Array) || value.is_a?(Hash) || value.is_a?(ActionController::Parameters)

      value
    end
  end
end

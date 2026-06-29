# frozen_string_literal: true

# rubocop:disable Metrics/ModuleLength
module Admin
  module ResourceRegistryDefinitions
    include ResourceRegistryBuilder
    include ResourceFilterDefinitions
    include Resources::MasterResources
    include Resources::SongResources
    include Resources::DisplayArtistResources
    include Resources::DamResources
    include Resources::JoysoundResources

    private

    def build_resources
      [
        original,
        original_song,
        karaoke_delivery_model,
        circle,
        song,
        display_artist,
        dam_song,
        dam_artist_url,
        joysound_song,
        joysound_music_post,
        song_with_dam_ouchikaraoke,
        song_with_joysound_utasuki
      ]
    end

    def delivery_karaoke_type_filter
      exact_filter(:karaoke_type, label: 'カラオケ種別', options: { DAM: 'DAM', JOYSOUND: 'JOYSOUND' })
    end

    def karaoke_type_filter
      filter(
        :karaoke_type,
        label: 'カラオケ種別',
        type: :radio,
        options: karaoke_type_options
      ) do |scope, value|
        case value
        when 'dam'
          scope.dam
        when 'joysound'
          scope.joysound
        when 'joysound_music_post'
          scope.music_post
        else
          scope
        end
      end
    end

    def karaoke_type_options
      {
        dam: 'DAM',
        joysound: 'JOYSOUND',
        joysound_music_post: 'JOYSOUND(うたスキ)'
      }
    end

    def karaoke_type_value_options
      {
        'DAM' => 'DAM',
        'JOYSOUND' => 'JOYSOUND',
        'JOYSOUND(うたスキ)' => 'JOYSOUND(うたスキ)'
      }
    end

    def music_service_filter
      filter(
        :music_service,
        label: '音楽配信',
        type: :presence_groups,
        options: {
          apple_music: 'Apple',
          youtube_music: 'YT Music',
          spotify: 'Spotify',
          line_music: 'LINE'
        }
      ) do |scope, values|
        apply_music_service_filters(scope, values)
      end
    end

    def video_service_filter
      filter(
        :video_service,
        label: '動画',
        type: :presence_groups,
        options: {
          youtube: 'YouTube',
          nicovideo: 'ニコニコ'
        }
      ) do |scope, values|
        apply_video_service_filters(scope, values)
      end
    end

    def apply_music_service_filters(scope, values)
      apply_presence_group_filters(
        scope,
        values,
        apple_music: :apple_music_url,
        youtube_music: :youtube_music_url,
        spotify: :spotify_url,
        line_music: :line_music_url
      )
    end

    def apply_video_service_filters(scope, values)
      apply_presence_group_filters(scope, values, youtube: :youtube_url, nicovideo: :nicovideo_url)
    end

    def artist_circle_filter
      filter(:artist_circle, label: 'アーティストのサークル', type: :radio, options: { present: 'サークルあり', blank: 'サークルなし' }) do |scope, value|
        case value
        when 'present'
          scope.left_outer_joins(display_artist: :circles).where.not(circles: { id: nil }).distinct
        when 'blank'
          scope.left_outer_joins(display_artist: :circles).where(circles: { id: nil }).distinct
        else
          scope
        end
      end
    end

    def dam_artist_url_registration_filter
      filter(:registration, label: '登録状況', type: :radio, options: { registered: '登録済み', unregistered: '未登録' }) do |scope, value|
        registered_urls = DisplayArtist.dam.select(:url)
        case value
        when 'registered'
          scope.where(url: registered_urls)
        when 'unregistered'
          scope.where.not(url: registered_urls)
        else
          scope
        end
      end
    end

    def joysound_service_filter
      filter(
        :service_enabled,
        label: '対応サービス',
        type: :radio,
        options: {
          smartphone: 'スマートフォン',
          home_karaoke: '家庭用カラオケ',
          both: '両方有効',
          none: 'どちらも無効'
        }
      ) do |scope, value|
        case value
        when 'smartphone'
          scope.where(smartphone_service_enabled: true)
        when 'home_karaoke'
          scope.where(home_karaoke_enabled: true)
        when 'both'
          scope.where(smartphone_service_enabled: true, home_karaoke_enabled: true)
        when 'none'
          scope.where(smartphone_service_enabled: false, home_karaoke_enabled: false)
        else
          scope
        end
      end
    end
  end
end
# rubocop:enable Metrics/ModuleLength

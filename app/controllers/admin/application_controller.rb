# All Administrate controllers inherit from this
# `Administrate::ApplicationController`, making it the ideal place to put
# authentication logic or other before_actions.
#
# If you want to add pagination or other controller-level concerns,
# you're free to overwrite the RESTful controller actions.
module Admin
  class ApplicationController < Administrate::ApplicationController
    before_action :authenticate_admin

    BROWSE_ONLY = %w[
      originals
      original_songs
      karaoke_delivery_models
      display_artists
      dam_songs
      joysound_songs
      joysound_music_posts
      song_with_joysound_utasukis
      song_with_dam_ouchikaraokes
      display_artists_circles
      songs_original_songs
      songs_karaoke_delivery_models
    ].freeze

    def authenticate_admin
      # TODO: Add authentication logic here.
    end

    # Override this value to specify the number of elements to display at a time
    # on index pages. Defaults to 20.
    # def records_per_page
    #   params[:per_page] || 20
    # end
    def valid_action?(name, resource = resource_class)
      case resource.to_s.underscore.pluralize
      when 'display_artists'
        %w[new edit].exclude?(name.to_s) && super
      when 'songs'
        %w[new destroy].exclude?(name.to_s) && super
      when 'circles', 'dam_artist_urls'
        %w[].exclude?(name.to_s) && super
      when *BROWSE_ONLY
        %w[new edit destroy].exclude?(name.to_s) && super
      end
    end

    def order
      @order ||= Administrate::Order.new(
        params.fetch(resource_name, {}).fetch(:order, default_sort[:order]),
        params.fetch(resource_name, {}).fetch(:direction, default_sort[:direction])
      )
    end

    # override this in specific controllers as needed
    def default_sort
      { order: :updated_at, direction: :desc }
    end
  end
end

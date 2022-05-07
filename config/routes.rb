require 'sidekiq/web'

Rails.application.routes.draw do
  mount Sidekiq::Web, at: "/admin/sidekiq"

  root to: "admin/songs#index"
  namespace :admin do
    resources :songs
    resources :originals
    resources :original_songs
    resources :karaoke_delivery_models
    resources :circles
    resources :display_artists
    namespace :dam_songs do
      resources :fetch_dam_songs, only: :index
    end
    resources :dam_songs
    namespace :joysound_songs do
      resources :fetch_joysound_songs, only: :index
    end
    resources :joysound_songs
    namespace :joysound_music_posts do
      resources :fetch_joysound_music_posts, only: :index
    end
    resources :joysound_music_posts
    resources :song_with_joysound_utasukis
    resources :song_with_dam_ouchikaraokes
    resources :dam_artist_urls
    resources :display_artists_circles
    resources :songs_original_songs
    resources :songs_karaoke_delivery_models

    root to: "songs#index"
  end
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end

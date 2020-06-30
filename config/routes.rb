Rails.application.routes.draw do
  root to: "admin/songs#index"
  namespace :admin do
      resources :songs
      resources :song_with_joysound_utasukis
      resources :joysound_music_posts
      resources :display_artists
      resources :originals
      resources :dam_artist_urls
      resources :display_artists_circles
      resources :songs_original_songs
      resources :dam_songs
      resources :songs_karaoke_delivery_models
      resources :song_with_dam_ouchikaraokes
      resources :joysound_songs
      resources :circles
      resources :karaoke_delivery_models
      resources :original_songs

      root to: "songs#index"
    end
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end

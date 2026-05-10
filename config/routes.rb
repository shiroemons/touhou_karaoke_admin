Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :admin do
    root to: "dashboard#show"

    resources :originals
    resources :original_songs
    resources :karaoke_delivery_models do
      get :operation, on: :member
      post :operation, on: :member
    end
    resources :circles
    resources :songs do
      get :operation, on: :collection
      post :operation, on: :collection
    end
    resources :display_artists do
      get :operation, on: :collection
      post :operation, on: :collection
    end
    resources :dam_songs do
      get :operation, on: :collection
      post :operation, on: :collection
    end
    resources :dam_artist_urls
    resources :joysound_songs do
      get :operation, on: :collection
      post :operation, on: :collection
    end
    resources :joysound_music_posts do
      get :operation, on: :collection
      post :operation, on: :collection
    end
    resources :song_with_dam_ouchikaraokes
    resources :song_with_joysound_utasukis
  end

  root to: redirect('/admin')
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end

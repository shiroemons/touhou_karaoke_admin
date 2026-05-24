Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :admin do
    root to: "dashboard#show"
    get :workflow, to: "workflow#index"
    get "workflow/:workflow_key", to: "workflow#show", as: :workflow_steps
    post "workflow/:workflow_key/run", to: "workflow#run", as: :run_workflow
    get "workflow/:workflow_key/progress", to: "workflow#progress", as: :workflow_progress
    get :karaoke_song_bulk_edit, to: "karaoke_song_bulk_edits#index"
    post :karaoke_song_bulk_edit, to: "karaoke_song_bulk_edits#update"
    get "karaoke_song_bulk_edit/original_song_options", to: "karaoke_song_bulk_edits#original_song_options", as: :karaoke_song_bulk_edit_original_song_options
    post "karaoke_song_bulk_edit/resolve_original_songs", to: "karaoke_song_bulk_edits#resolve_original_songs", as: :karaoke_song_bulk_edit_resolve_original_songs

    resources :originals
    resources :original_songs
    resources :karaoke_delivery_models do
      get :operation, on: :member
      post :operation, on: :member
      get :operation_progress, on: :member
    end
    resources :circles
    resources :songs do
      get :operation, on: :collection
      post :operation, on: :collection
      get :operation_progress, on: :collection
    end
    resources :display_artists do
      get :operation, on: :collection
      post :operation, on: :collection
      get :operation_progress, on: :collection
    end
    resources :dam_songs do
      get :operation, on: :collection
      post :operation, on: :collection
      get :operation_progress, on: :collection
    end
    resources :dam_artist_urls
    resources :joysound_songs do
      get :operation, on: :collection
      post :operation, on: :collection
      get :operation_progress, on: :collection
    end
    resources :joysound_music_posts do
      get :operation, on: :collection
      post :operation, on: :collection
      get :operation_progress, on: :collection
    end
    resources :song_with_dam_ouchikaraokes
    resources :song_with_joysound_utasukis
  end

  root to: redirect('/admin')
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end

require 'sidekiq/web'

Rails.application.routes.draw do
  mount Avo::Engine, at: Avo.configuration.root_path
  mount Sidekiq::Web, at: "/sidekiq"
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end

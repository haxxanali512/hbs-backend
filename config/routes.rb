Rails.application.routes.draw do
  devise_for :users
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "health#show", as: :rails_health_check

  # API routes
  namespace :api do
    namespace :v1 do
      resources :file_uploads, only: [ :create ] do
        collection do
          get :status
        end
      end
    end
  end

  # Sidekiq web interface (for monitoring jobs)
  require "sidekiq/web"
  mount Sidekiq::Web => "/sidekiq"

  # Home routes
  root "home#index"
  get "dashboard", to: "home#dashboard"

  # Admin namespace
  namespace :admin do
    resources :roles do
      member do
        get :permissions
        patch :update_permissions
        post :duplicate
      end
    end
  end

  # Defines the root path route ("/")
  # root "health#show"
end

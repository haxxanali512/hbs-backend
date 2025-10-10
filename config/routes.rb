Rails.application.routes.draw do
  devise_for :users, controllers: { invitations: "users/invitations" }
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

  # Global admin routes (no subdomain or 'admin' subdomain)
  constraints subdomain: /^(www|admin)?$/ do
    # Home routes
    root "home#index", as: :global_root
    get "dashboard", to: "home#dashboard"

    namespace :admin do
      get "dashboard", to: "dashboard#index"
      resources :organizations do
        member do
          post :activate_tenant
          post :suspend_tenant
        end
      end
      resources :users, except: [ :show ] do
        member do
          post :suspend
          post :activate
          post :deactivate
          post :reset_password
          get  :reset_password
          post :reinvite
          patch :change_role
        end
        collection do
          get :invite
          post :send_invitation
        end
      end
      resources :roles do
        member do
          get :permissions
          patch :update_permissions
          post :duplicate
        end
      end
      resources :organization_billings do
        member do
          patch :approve
          patch :reject
        end
      end
    end
  end

  # Organization-specific routes (tenant subdomains)
  constraints subdomain: /(?!www|admin).+/ do
    root "organizations#dashboard", as: :tenant_root
    get "dashboard", to: "organizations#dashboard"

    # Tenant-scoped resources
    namespace :tenant do
      # resources :patients
      # resources :claims
      # resources :invoices
      # resources :reports
      resources :team_members, only: [ :index, :show, :edit, :update ]
    end

    # Activation wizard (tenant context)
    get "activation", to: "activation#index"
    get "activation/billing", to: "activation#billing_setup"
    patch "activation/billing", to: "activation#update_billing"
    post "activation/manual_payment", to: "activation#manual_payment"
    get "activation/compliance", to: "activation#compliance_setup"
    patch "activation/compliance", to: "activation#update_compliance"
    get "activation/documents", to: "activation#document_signing"
    post "activation/documents", to: "activation#complete_document_signing"
    get "activation/complete", to: "activation#complete"
    post "activation/activate", to: "activation#activate"
  end

  # Stripe integration routes
  namespace :stripe do
    get :products
    get "products/:id/prices", to: "stripe#product_prices"
    post :create_checkout_session
    get "checkout_session/:id", to: "stripe#checkout_session"
    post :webhook
  end

  # GoCardless integration routes
  namespace :gocardless do
    get :customers
    post :customers
    get "customers/:id", to: "gocardless#customer"
    get "customers/:id/payments", to: "gocardless#customer_payments"
    post :create_redirect_flow
    post "redirect_flow/:id/complete", to: "gocardless#complete_redirect_flow"
    post :mandates
    post :payments
    post :subscriptions
    get "subscriptions/:id", to: "gocardless#subscription"
    delete "subscriptions/:id", to: "gocardless#cancel_subscription"
    post :webhook
  end

  # Defines the root path route ("/")
  # root "health#show"
end

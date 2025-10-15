Rails.application.routes.draw do
  devise_for :users, controllers: { invitations: "users/invitations" }

  # Health check
  get "up" => "health#show", as: :rails_health_check

  # API routes
  namespace :api do
    namespace :v1 do
      resources :file_uploads, only: [ :create ] do
        collection { get :status }
      end
    end
  end

  # Sidekiq dashboard
  require "sidekiq/web"
  mount Sidekiq::Web => "/sidekiq"

  # ===========================================================
  # 🧭 ADMIN (default + admin subdomain)
  # ===========================================================
  constraints subdomain: /^(www|admin)?$/ do
    root "admin/dashboard#index", as: :global_root
    get "admin/dashboard", to: "admin/dashboard#index"

    namespace :admin do
      root "dashboard#index", as: :root

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

  # ===========================================================
  # 🧩 TENANT (org subdomains)
  # ===========================================================
  constraints subdomain: /^(?!www|admin$).+/ do
    root "tenant/dashboard#index", as: :tenant_root
    get "dashboard", to: "tenant/dashboard#index"

    namespace :tenant do
      get "dashboard", to: "dashboard#index"

      # Activation wizard (moved to dashboard)
      get "activation",                 to: "dashboard#activation"
      get "activation/billing",         to: "dashboard#billing_setup"
      patch "activation/billing",       to: "dashboard#update_billing"
      post "activation/manual_payment", to: "dashboard#manual_payment"
      get "activation/stripe_card",     to: "dashboard#stripe_card"
      post "activation/stripe_card",    to: "dashboard#save_stripe_card"

      # DocuSign endpoints
      post "activation/send_gsa_agreement", to: "dashboard#send_gsa_agreement"
      post "activation/send_baa_agreement", to: "dashboard#send_baa_agreement"
      get "activation/docusign_status",     to: "dashboard#check_docusign_status"

      get "activation/compliance",      to: "dashboard#compliance_setup"
      patch "activation/compliance",    to: "dashboard#update_compliance"

      get "activation/documents",       to: "dashboard#document_signing"
      post "activation/documents",      to: "dashboard#complete_document_signing"

      get "activation/complete",        to: "dashboard#activation_complete"
      post "activation/activate",       to: "dashboard#activate"

      # (optional) tenant resources like patients, claims, etc.
      # resources :patients
      # resources :claims
      # resources :invoices
      # resources :team_members
    end
  end

  # ===========================================================
  # 💳 Stripe Integration
  # ===========================================================
  scope path: "/stripe" do
    get ":products", to: "stripe#products", as: :stripe_products, constraints: { products: /products/ }
    get "products/:id/prices", to: "stripe#product_prices", as: :stripe_product_prices
    post "create_checkout_session", to: "stripe#create_checkout_session", as: :stripe_create_checkout_session
    get "checkout_session/:id", to: "stripe#checkout_session", as: :stripe_checkout_session
    post "setup_intent", to: "stripe#setup_intent", as: :stripe_setup_intent
    post "confirm_card", to: "stripe#confirm_card", as: :stripe_confirm_card
    post "webhook", to: "stripe#webhook", as: :stripe_webhook
  end

  # ===========================================================
  # 💰 GoCardless Integration
  # ===========================================================
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
end

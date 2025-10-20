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
  # ADMIN Routes
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

      resources :invoices do
        member do
          post :issue
          post :void
          post :apply_payment
          get  :download_pdf
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
      get "activation",                 to: "activation#index"
      get "activation/billing",         to: "activation#billing_setup"
      patch "activation/billing",       to: "activation#update_billing"
      post "activation/manual_payment", to: "activation#manual_payment"
      get "activation/stripe_card",     to: "activation#stripe_card"
      post "activation/stripe_card",    to: "activation#save_stripe_card"

      # DocuSign endpoints
      post "activation/send_agreement", to: "activation#send_agreement"
      get "activation/docusign_status",     to: "activation#check_docusign_status"

      get "activation/compliance",      to: "activation#compliance_setup"
      patch "activation/compliance",    to: "activation#update_compliance"

      get "activation/documents",       to: "activation#document_signing"
      post "activation/documents",      to: "activation#complete_document_signing"

      get "activation/complete",        to: "activation#activation_complete"
      post "activation/activate",       to: "activation#activate"

      scope path: "/stripe" do
        get ":products", to: "stripe#products", as: :stripe_products, constraints: { products: /products/ }
        get "products/:id/prices", to: "stripe#product_prices", as: :stripe_product_prices
        post "create_checkout_session", to: "stripe#create_checkout_session", as: :stripe_create_checkout_session
        get "checkout_session/:id", to: "stripe#checkout_session", as: :stripe_checkout_session
        post "setup_intent", to: "stripe#setup_intent", as: :stripe_setup_intent
        post "confirm_card", to: "stripe#confirm_card", as: :stripe_confirm_card
        post "webhook", to: "stripe#webhook", as: :stripe_webhook
      end

        scope path: "/gocardless" do
          post "create_redirect_flow", to: "gocardless#create_redirect_flow"
          get "redirect_flow/complete", to: "gocardless#complete_redirect_flow"
          post "webhook", to: "gocardless#webhook"
        end
        resources :invoices, only: [ :index, :show ] do
          member do
            get :pay
            get :download_pdf
          end
        end

        resources :providers
      end


      # Invoice management

      # (optional) tenant resources like patients, claims, etc.
      # resources :patients
      # resources :claims
      # resources :team_members
    end
  end

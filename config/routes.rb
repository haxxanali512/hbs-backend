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

      resources :organization_locations, only: [ :index, :show, :edit, :update ] do
        member do
          post :activate
          post :inactivate
        end
      end

      resources :audits, only: [ :index, :show ] do
        collection do
          get :model_audits
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

      resources :payers

      resources :providers do
        member do
          post :approve
          post :reject
          post :suspend
          post :reactivate
          post :resubmit
        end
        collection do
          post :bulk_approve
          post :bulk_reject
        end
      end

      resources :specialties do
        member do
          post :retire
          get :impact_analysis
          get :list_providers
          patch :update_allowed_codes
        end
      end

      resources :fee_schedules do
        member do
          post :lock
          post :unlock
        end
        resources :fee_schedule_items do
          member do
            post :activate
            post :deactivate
            post :lock
            post :unlock
          end
        end
      end

      resources :procedure_codes do
        member do
          post :toggle_status
        end
      end

      resources :diagnosis_codes do
        member do
          post :retire
          post :activate
        end
      end

      resources :appointments, only: [ :index, :show, :edit, :update, :destroy ]

      resources :encounters, only: [ :index, :show, :edit, :update, :destroy ] do
        member do
          post :cancel
          post :request_correction
          post :override_validation
        end
      end

      resources :claims do
        member do
          post :validate
          post :submit
          post :post_adjudication
          post :void
          post :reverse
          post :close
        end
        resources :denials, only: [ :index, :show, :create, :update ] do
          member do
            post :update_status
            post :resubmit
            post :mark_non_correctable
            post :override_attempt_limit
            post :attach_doc
            delete :remove_doc
          end
          resources :denial_items, only: [ :create, :update ]
        end
        resources :claim_submissions, only: [ :index, :create ] do
          member do
            post :resubmit
            post :void
            post :replace
          end
        end
        resources :claim_lines, only: [ :index, :show, :edit, :update ] do
          member do
            post :post_adjudication
          end
        end
      end

      resources :patients, only: [ :index, :show, :edit, :update, :destroy ] do
        member do
          post :activate
          post :inactivate
          post :mark_deceased
          post :reactivate
        end
      end
    end
  end

  # ===========================================================
  # TENANT (org subdomains)
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
        resources :specialties, only: [ :index, :show ]
        resources :organization_locations do
          member do
            post :activate
            post :inactivate
            post :reactivate
          end
        end

        resources :fee_schedules do
          member do
            post :lock
            post :unlock
          end
          resources :fee_schedule_items do
            member do
              post :activate
              post :deactivate
            end
          end
        end

        resources :procedure_codes, only: [ :index, :show ]

        resources :diagnosis_codes, only: [ :index, :show ] do
          member do
            post :request_review
          end
        end

        resources :appointments do
          member do
            post :cancel
            post :complete
            post :mark_no_show
          end
        end

        resources :encounters do
          member do
            post :confirm_completed
            post :cancel
            post :request_correction
            post :attach_document
          end
        end

        resources :patients do
          member do
            post :activate
            post :inactivate
            post :mark_deceased
            post :reactivate
          end
        end

        resource :organization_setting, only: [ :show, :edit, :update ]
      end
    end
  end

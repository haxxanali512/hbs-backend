Rails.application.routes.draw do
  devise_for :users, controllers: {
    invitations: "users/invitations",
    masquerades: "admin/masquerades"
  }

  # Health check
  get "up" => "health#show", as: :rails_health_check

  # Notifications (available in both admin and tenant)
  resources :notifications, only: [ :index ] do
    member do
      patch :mark_as_read
    end
    collection do
      patch :mark_all_as_read
      get :unread_count
    end
  end

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

  # Letter Opener Web (for viewing emails in production)
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.production? || Rails.env.development?

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

      resources :payers do
        collection do
          get :fetch_from_ezclaim
          post :save_from_ezclaim
        end
      end

      resources :data_exports_imports, only: [ :index ] do
        collection do
          get :download_sample
          get :download_processing_sample
          post :export
          post :import
          post :upload_processing_file
        end
      end

      resources :email_template_keys do
        resources :email_templates, only: %i[new create]
      end
      resources :email_templates, only: %i[index show edit update destroy]

      resources :support_tickets do
        member do
          patch :close
          patch :reopen
          post :add_internal_note
          post :attach_document
        end

        resources :comments,
                  only: [ :create ],
                  controller: "support_ticket_comments"
      end

      resources :insurance_plans do
        member do
          post :retire
          post :restore
        end
      end

      resources :org_accepted_plans do
        member do
          post :activate
          post :inactivate
          post :lock
          post :unlock
        end
      end

      resources :patient_insurance_coverages do
        member do
          post :activate
          post :terminate
          post :replace
          post :run_eligibility
        end
      end

      resources :payer_enrollments do
        member do
          post :submit
          post :cancel
          post :resubmit
        end
      end

      resources :providers do
        collection do
          get :fetch_from_ezclaim
          post :save_from_ezclaim
        end
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
          post :push_to_ezclaim
        end
      end

      resources :diagnosis_codes do
        member do
          post :retire
          post :activate
        end
      end

      resources :appointments, only: [ :index, :show, :edit, :update, :destroy ]

      resources :encounters do
        collection do
          get :fetch_from_ezclaim
          post :save_from_ezclaim
        end
        member do
          post :cancel
          post :request_correction
          post :override_validation
          get :billing_data
          get :procedure_codes_search
          get :diagnosis_codes_search
          post :submit_for_billing
        end
        resources :encounter_comments, only: [ :index, :create ] do
          member do
            post :redact
          end
        end
        resources :provider_notes, only: [ :index, :show ]
      end

      resources :claims do
        member do
          post :validate
          post :submit
          get :test_ezclaim_connection
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
        collection do
          get :fetch_from_ezclaim
          post :save_from_ezclaim
        end
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
        resources :specialties
        resources :organization_locations do
          member do
            post :activate
            post :inactivate
            post :reactivate
          end
        end

        resources :fee_schedules, only: [ :index, :show ] do
          member do
            post :lock
            post :unlock
          end
          resources :fee_schedule_items, only: [ :update ]
        end

        resources :procedure_codes, only: [ :index, :show ] do
          collection do
            get :search
          end
        end

        resources :diagnosis_codes, only: [ :index, :show ] do
          collection do
            get :search
          end
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
          collection do
            get :workflow
            post :submit_queued
          end
          member do
            post :mark_reviewed
            post :mark_ready_to_submit
            post :cancel
            post :request_correction
            post :attach_document
            get :billing_data
            get :procedure_codes_search
            get :diagnosis_codes_search
            post :submit_for_billing
          end
          resources :encounter_comments, only: [ :index, :create ]
          resources :provider_notes, except: [ :show ]
        end

        resources :support_tickets, only: [ :index, :new, :create, :show ] do
          member do
            post :attach_document
          end

          resources :comments,
                    only: [ :create ],
                    controller: "support_ticket_comments"
        end

        resources :payer_enrollments, only: [ :index ]

        resources :org_accepted_plans do
          member do
            post :activate
            post :inactivate
          end
        end

        resources :patient_insurance_coverages do
          member do
            post :activate
            post :terminate
            post :replace
            post :run_eligibility
          end
        end

        resources :patients do
          member do
            post :activate
            post :inactivate
            post :mark_deceased
            post :reactivate
            post :push_to_ezclaim
          end
        end

        # Claims index removed per request; comment out tenant claims routes
        # resources :claims, only: [ :index, :show ]

        resource :organization_setting, only: [ :show, :edit, :update ]
      end
    end
  end

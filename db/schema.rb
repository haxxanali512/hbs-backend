# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2025_10_17_121351) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "invoice_line_items", force: :cascade do |t|
    t.uuid "invoice_id", null: false
    t.string "description", null: false
    t.decimal "quantity", precision: 10, scale: 2
    t.decimal "unit_price", precision: 10, scale: 2
    t.decimal "percent_applied", precision: 5, scale: 2
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.jsonb "calc_ref"
    t.integer "position", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["invoice_id"], name: "index_invoice_line_items_on_invoice_id"
    t.index ["position"], name: "index_invoice_line_items_on_position"
  end

  create_table "invoices", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "invoice_number", null: false
    t.bigint "organization_id", null: false
    t.integer "invoice_type", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.date "issue_date"
    t.date "due_date"
    t.date "service_period_start"
    t.date "service_period_end"
    t.string "service_month"
    t.string "currency", default: "USD", null: false
    t.decimal "subtotal", precision: 10, scale: 2, default: "0.0"
    t.decimal "total", precision: 10, scale: 2, default: "0.0"
    t.decimal "amount_paid", precision: 10, scale: 2, default: "0.0"
    t.decimal "amount_credited", precision: 10, scale: 2, default: "0.0"
    t.decimal "amount_due", precision: 10, scale: 2, default: "0.0"
    t.decimal "percent_of_revenue_snapshot", precision: 5, scale: 2
    t.decimal "collected_revenue_amount", precision: 10, scale: 2
    t.integer "deductible_applied_claims_count"
    t.decimal "deductible_fee_snapshot", precision: 10, scale: 2, default: "10.0"
    t.decimal "adjustments_total", precision: 10, scale: 2, default: "0.0"
    t.datetime "latest_payment_at"
    t.integer "exception_type"
    t.text "exception_reason"
    t.date "exception_through"
    t.bigint "exception_set_by_user_id"
    t.datetime "exception_set_at"
    t.text "notes_internal"
    t.text "notes_client"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["due_date"], name: "index_invoices_on_due_date"
    t.index ["exception_set_by_user_id"], name: "index_invoices_on_exception_set_by_user_id"
    t.index ["invoice_number"], name: "index_invoices_on_invoice_number", unique: true
    t.index ["invoice_type"], name: "index_invoices_on_invoice_type"
    t.index ["organization_id", "service_month"], name: "index_invoices_on_organization_id_and_service_month"
    t.index ["organization_id"], name: "index_invoices_on_organization_id"
    t.index ["service_month"], name: "index_invoices_on_service_month"
    t.index ["status"], name: "index_invoices_on_status"
  end

  create_table "organization_billings", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.integer "billing_status"
    t.datetime "last_payment_date", precision: nil
    t.datetime "next_payment_due", precision: nil
    t.string "method_last4"
    t.integer "provider"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "stripe_customer_id"
    t.string "stripe_subscription_id"
    t.string "stripe_session_id"
    t.string "stripe_payment_method_id"
    t.string "card_brand"
    t.integer "card_exp_month"
    t.integer "card_exp_year"
    t.string "gocardless_customer_id"
    t.string "gocardless_mandate_id"
    t.index ["organization_id"], name: "index_organization_billings_on_organization_id"
    t.index ["stripe_customer_id"], name: "index_organization_billings_on_stripe_customer_id"
    t.index ["stripe_subscription_id"], name: "index_organization_billings_on_stripe_subscription_id"
  end

  create_table "organization_compliances", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.datetime "gsa_signed_at", precision: nil
    t.string "gsa_envelope_id"
    t.datetime "baa_signed_at", precision: nil
    t.string "baa_envelope_id"
    t.datetime "phi_access_locked_at", precision: nil
    t.datetime "data_retention_expires_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "privacy_policy_accepted", default: false
    t.boolean "terms_of_use", default: false
    t.index ["organization_id"], name: "index_organization_compliances_on_organization_id"
  end

  create_table "organization_contacts", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.text "address_line1"
    t.text "address_line2"
    t.string "city"
    t.string "state"
    t.string "zip"
    t.string "country"
    t.string "phone"
    t.string "email"
    t.string "time_zone"
    t.integer "contact_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_organization_contacts_on_organization_id"
  end

  create_table "organization_identifiers", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.string "tax_identification_number"
    t.string "npi"
    t.integer "identifiers_change_status"
    t.string "identifiers_change_docs"
    t.string "previous_tin"
    t.string "previous_npi"
    t.datetime "identifiers_change_effective_on", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_organization_identifiers_on_organization_id"
  end

  create_table "organization_memberships", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "organization_id", null: false
    t.bigint "organization_role_id"
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_organization_memberships_on_organization_id"
    t.index ["organization_role_id"], name: "index_organization_memberships_on_organization_role_id"
    t.index ["user_id", "organization_id"], name: "index_organization_memberships_on_user_id_and_organization_id", unique: true
    t.index ["user_id"], name: "index_organization_memberships_on_user_id"
  end

  create_table "organization_settings", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.jsonb "feature_entitlements"
    t.string "mrn_prefix"
    t.string "mrn_sequence"
    t.string "mrn_format"
    t.string "mrn_enabled"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_organization_settings_on_organization_id"
  end

  create_table "organizations", force: :cascade do |t|
    t.string "name"
    t.string "subdomain"
    t.bigint "owner_id", null: false
    t.string "tier"
    t.integer "activation_status"
    t.datetime "activation_state_changed_at", precision: nil
    t.datetime "closed_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_id"], name: "index_organizations_on_owner_id"
  end

  create_table "payments", force: :cascade do |t|
    t.uuid "invoice_id", null: false
    t.bigint "organization_id", null: false
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.integer "payment_method", default: 0, null: false
    t.string "payment_provider_id"
    t.jsonb "payment_provider_response"
    t.integer "payment_status", default: 0, null: false
    t.datetime "paid_at"
    t.bigint "processed_by_user_id"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["invoice_id", "payment_status"], name: "index_payments_on_invoice_id_and_payment_status"
    t.index ["invoice_id"], name: "index_payments_on_invoice_id"
    t.index ["organization_id", "paid_at"], name: "index_payments_on_organization_id_and_paid_at"
    t.index ["organization_id"], name: "index_payments_on_organization_id"
    t.index ["paid_at"], name: "index_payments_on_paid_at"
    t.index ["payment_provider_id"], name: "index_payments_on_payment_provider_id"
    t.index ["payment_status"], name: "index_payments_on_payment_status"
    t.index ["processed_by_user_id"], name: "index_payments_on_processed_by_user_id"
  end

  create_table "remit_captures", force: :cascade do |t|
    t.string "capturable_type", null: false
    t.bigint "capturable_id", null: false
    t.integer "capture_type", default: 0, null: false
    t.string "capture_ref"
    t.string "label"
    t.date "service_period_start"
    t.date "service_period_end"
    t.string "file_path"
    t.integer "file_size"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["capturable_type", "capturable_id"], name: "index_remit_captures_on_capturable"
    t.index ["capturable_type", "capturable_id"], name: "index_remit_captures_on_capturable_type_and_capturable_id"
    t.index ["service_period_start", "service_period_end"], name: "idx_on_service_period_start_service_period_end_a4be37828a"
  end

  create_table "roles", force: :cascade do |t|
    t.string "role_name"
    t.jsonb "access"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "scope", default: 0
    t.bigint "organization_id"
    t.index ["organization_id"], name: "index_roles_on_organization_id"
    t.index ["scope", "organization_id"], name: "index_roles_on_scope_and_organization_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "username"
    t.string "first_name"
    t.string "last_name"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.integer "failed_attempts", default: 0, null: false
    t.string "unlock_token"
    t.datetime "locked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "role_id"
    t.string "invitation_token"
    t.datetime "invitation_created_at"
    t.datetime "invitation_sent_at"
    t.datetime "invitation_accepted_at"
    t.integer "invitation_limit"
    t.string "invited_by_type"
    t.bigint "invited_by_id"
    t.integer "invitations_count", default: 0
    t.integer "status"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["invitation_token"], name: "index_users_on_invitation_token", unique: true
    t.index ["invited_by_id"], name: "index_users_on_invited_by_id"
    t.index ["invited_by_type", "invited_by_id"], name: "index_users_on_invited_by"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role_id"], name: "index_users_on_role_id"
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

  add_foreign_key "invoice_line_items", "invoices"
  add_foreign_key "invoices", "organizations"
  add_foreign_key "invoices", "users", column: "exception_set_by_user_id"
  add_foreign_key "organization_billings", "organizations"
  add_foreign_key "organization_compliances", "organizations"
  add_foreign_key "organization_contacts", "organizations"
  add_foreign_key "organization_identifiers", "organizations"
  add_foreign_key "organization_memberships", "organizations"
  add_foreign_key "organization_memberships", "roles", column: "organization_role_id"
  add_foreign_key "organization_memberships", "users"
  add_foreign_key "organization_settings", "organizations"
  add_foreign_key "organizations", "users", column: "owner_id"
  add_foreign_key "payments", "invoices"
  add_foreign_key "payments", "organizations"
  add_foreign_key "payments", "users", column: "processed_by_user_id"
  add_foreign_key "roles", "organizations"
  add_foreign_key "users", "roles"
end

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

ActiveRecord::Schema[7.2].define(version: 2025_10_21_144436) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "audits", force: :cascade do |t|
    t.integer "auditable_id"
    t.string "auditable_type"
    t.integer "associated_id"
    t.string "associated_type"
    t.integer "user_id"
    t.string "user_type"
    t.string "username"
    t.string "action"
    t.text "audited_changes"
    t.integer "version", default: 0
    t.string "comment"
    t.string "remote_address"
    t.string "request_uuid"
    t.datetime "created_at"
    t.index ["associated_type", "associated_id"], name: "associated_index"
    t.index ["auditable_type", "auditable_id", "version"], name: "auditable_index"
    t.index ["created_at"], name: "index_audits_on_created_at"
    t.index ["request_uuid"], name: "index_audits_on_request_uuid"
    t.index ["user_id", "user_type"], name: "user_index"
  end

  create_table "diagnosis_codes", force: :cascade do |t|
    t.string "code"
    t.text "description"
    t.integer "status"
    t.datetime "effective_from"
    t.datetime "effective_to"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "document_attachments", force: :cascade do |t|
    t.bigint "document_id", null: false
    t.string "file_name", null: false
    t.string "file_type"
    t.integer "file_size"
    t.string "file_path", null: false
    t.string "file_hash"
    t.boolean "is_primary", default: false
    t.bigint "uploaded_by_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["document_id"], name: "index_document_attachments_on_document_id"
    t.index ["file_hash"], name: "index_document_attachments_on_file_hash"
    t.index ["is_primary"], name: "index_document_attachments_on_is_primary"
    t.index ["uploaded_by_id"], name: "index_document_attachments_on_uploaded_by_id"
  end

  create_table "documents", force: :cascade do |t|
    t.string "documentable_type", null: false
    t.bigint "documentable_id", null: false
    t.string "title", null: false
    t.text "description"
    t.string "status", default: "draft"
    t.string "document_type"
    t.date "document_date"
    t.bigint "created_by_id", null: false
    t.bigint "organization_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_documents_on_created_by_id"
    t.index ["document_type"], name: "index_documents_on_document_type"
    t.index ["documentable_type", "documentable_id"], name: "index_documents_on_documentable"
    t.index ["documentable_type", "documentable_id"], name: "index_documents_on_documentable_type_and_documentable_id"
    t.index ["organization_id"], name: "index_documents_on_organization_id"
    t.index ["status"], name: "index_documents_on_status"
  end

  create_table "encounter_diagnosis_codes", force: :cascade do |t|
    t.bigint "diagnosis_code_id", null: false
    t.bigint "encounter_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["diagnosis_code_id"], name: "index_encounter_diagnosis_codes_on_diagnosis_code_id"
    t.index ["encounter_id"], name: "index_encounter_diagnosis_codes_on_encounter_id"
  end

  create_table "encounters", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "patient_id", null: false
    t.bigint "provider_id", null: false
    t.date "date_of_service"
    t.bigint "specialty_id", null: false
    t.integer "billing_channel"
    t.text "notes"
    t.jsonb "coverage_snapshot"
    t.jsonb "pricing_snapshot"
    t.integer "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_encounters_on_organization_id"
    t.index ["patient_id"], name: "index_encounters_on_patient_id"
    t.index ["provider_id"], name: "index_encounters_on_provider_id"
    t.index ["specialty_id"], name: "index_encounters_on_specialty_id"
  end

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

  create_table "organization_fee_schedule_items", force: :cascade do |t|
    t.bigint "organization_fee_schedule_id", null: false
    t.bigint "procedure_code_id", null: false
    t.decimal "unit_price", precision: 10, scale: 2, null: false
    t.string "pricing_rule", null: false
    t.boolean "active", default: true, null: false
    t.boolean "locked", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_organization_fee_schedule_items_on_active"
    t.index ["locked"], name: "index_organization_fee_schedule_items_on_locked"
    t.index ["organization_fee_schedule_id", "procedure_code_id"], name: "index_fee_schedule_items_on_schedule_and_procedure", unique: true
    t.index ["organization_fee_schedule_id"], name: "idx_on_organization_fee_schedule_id_8245e30deb"
    t.index ["procedure_code_id"], name: "index_organization_fee_schedule_items_on_procedure_code_id"
  end

  create_table "organization_fee_schedules", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "provider_id", null: false
    t.string "name"
    t.integer "currency"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "discarded_at", precision: nil
    t.index ["organization_id"], name: "index_organization_fee_schedules_on_organization_id"
    t.index ["provider_id"], name: "index_organization_fee_schedules_on_provider_id"
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
    t.datetime "discarded_at"
    t.index ["discarded_at"], name: "index_organizations_on_discarded_at"
    t.index ["owner_id"], name: "index_organizations_on_owner_id"
  end

  create_table "patients", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.string "first_name"
    t.string "last_name"
    t.datetime "dob"
    t.string "sex_at_birth"
    t.text "address_line_1"
    t.text "address_line_2"
    t.string "city"
    t.string "state"
    t.string "postal"
    t.string "country"
    t.string "phone_number"
    t.string "email"
    t.string "mrn"
    t.string "external_id"
    t.integer "status"
    t.datetime "deceased_at", precision: nil
    t.text "notes_nonphi"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_patients_on_organization_id"
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

  create_table "procedure_codes", force: :cascade do |t|
    t.string "code"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "code_type", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.datetime "discarded_at"
    t.index ["code", "code_type"], name: "index_procedure_codes_on_code_and_code_type", unique: true
    t.index ["code_type"], name: "index_procedure_codes_on_code_type"
    t.index ["discarded_at"], name: "index_procedure_codes_on_discarded_at"
    t.index ["status"], name: "index_procedure_codes_on_status"
  end

  create_table "procedure_codes_specialties", force: :cascade do |t|
    t.bigint "specialty_id", null: false
    t.bigint "procedure_code_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["procedure_code_id"], name: "index_procedure_codes_specialties_on_procedure_code_id"
    t.index ["specialty_id"], name: "index_procedure_codes_specialties_on_specialty_id"
  end

  create_table "provider_assignments", force: :cascade do |t|
    t.bigint "provider_id", null: false
    t.bigint "organization_id", null: false
    t.integer "role"
    t.boolean "active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_provider_assignments_on_organization_id"
    t.index ["provider_id"], name: "index_provider_assignments_on_provider_id"
  end

  create_table "providers", force: :cascade do |t|
    t.string "first_name", limit: 100, null: false
    t.string "last_name", limit: 100, null: false
    t.string "npi", limit: 10
    t.string "license_number"
    t.string "license_state", limit: 2
    t.uuid "specialty_id", null: false
    t.uuid "user_id"
    t.string "status", default: "draft", null: false
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "discarded_at"
    t.index ["discarded_at"], name: "index_providers_on_discarded_at"
    t.index ["npi"], name: "index_providers_on_npi", unique: true, where: "(npi IS NOT NULL)"
    t.index ["specialty_id"], name: "index_providers_on_specialty_id"
    t.index ["user_id"], name: "index_providers_on_user_id"
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
    t.datetime "discarded_at"
    t.index ["discarded_at"], name: "index_roles_on_discarded_at"
  end

  create_table "specialties", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.integer "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "discarded_at"
    t.index ["discarded_at"], name: "index_specialties_on_discarded_at"
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
    t.datetime "discarded_at"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["discarded_at"], name: "index_users_on_discarded_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["invitation_token"], name: "index_users_on_invitation_token", unique: true
    t.index ["invited_by_id"], name: "index_users_on_invited_by_id"
    t.index ["invited_by_type", "invited_by_id"], name: "index_users_on_invited_by"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role_id"], name: "index_users_on_role_id"
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

  add_foreign_key "document_attachments", "documents"
  add_foreign_key "document_attachments", "users", column: "uploaded_by_id"
  add_foreign_key "documents", "organizations"
  add_foreign_key "documents", "users", column: "created_by_id"
  add_foreign_key "encounter_diagnosis_codes", "diagnosis_codes"
  add_foreign_key "encounter_diagnosis_codes", "encounters"
  add_foreign_key "encounters", "organizations"
  add_foreign_key "encounters", "patients"
  add_foreign_key "encounters", "providers"
  add_foreign_key "encounters", "specialties"
  add_foreign_key "invoice_line_items", "invoices"
  add_foreign_key "invoices", "organizations"
  add_foreign_key "invoices", "users", column: "exception_set_by_user_id"
  add_foreign_key "organization_billings", "organizations"
  add_foreign_key "organization_compliances", "organizations"
  add_foreign_key "organization_contacts", "organizations"
  add_foreign_key "organization_fee_schedule_items", "organization_fee_schedules"
  add_foreign_key "organization_fee_schedule_items", "procedure_codes"
  add_foreign_key "organization_fee_schedules", "organizations"
  add_foreign_key "organization_fee_schedules", "providers"
  add_foreign_key "organization_identifiers", "organizations"
  add_foreign_key "organization_memberships", "organizations"
  add_foreign_key "organization_memberships", "roles", column: "organization_role_id"
  add_foreign_key "organization_memberships", "users"
  add_foreign_key "organization_settings", "organizations"
  add_foreign_key "organizations", "users", column: "owner_id"
  add_foreign_key "patients", "organizations"
  add_foreign_key "payments", "invoices"
  add_foreign_key "payments", "organizations"
  add_foreign_key "payments", "users", column: "processed_by_user_id"
  add_foreign_key "procedure_codes_specialties", "procedure_codes"
  add_foreign_key "procedure_codes_specialties", "specialties"
  add_foreign_key "provider_assignments", "organizations"
  add_foreign_key "provider_assignments", "providers"
  add_foreign_key "users", "roles"
end

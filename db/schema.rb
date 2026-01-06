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

ActiveRecord::Schema[7.2].define(version: 2025_12_31_093210) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "appointments", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "organization_location_id", null: false
    t.bigint "provider_id", null: false
    t.bigint "patient_id", null: false
    t.bigint "specialty_id", null: false
    t.integer "appointment_type"
    t.integer "status"
    t.datetime "scheduled_start_at", precision: nil
    t.datetime "scheduled_end_at", precision: nil
    t.datetime "actual_start_at", precision: nil
    t.datetime "actual_end_at", precision: nil
    t.integer "duration_minutes"
    t.text "reason_for_visit"
    t.text "notes"
    t.datetime "discarded_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_appointments_on_organization_id"
    t.index ["organization_location_id"], name: "index_appointments_on_organization_location_id"
    t.index ["patient_id"], name: "index_appointments_on_patient_id"
    t.index ["provider_id"], name: "index_appointments_on_provider_id"
    t.index ["specialty_id"], name: "index_appointments_on_specialty_id"
  end

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

  create_table "claim_gen_payer_routes", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "payer_id", null: false
    t.string "claimgen_account_key", null: false
    t.string "external_payer_code"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "payer_id", "claimgen_account_key"], name: "idx_claimgen_routes_unique", unique: true
    t.index ["organization_id"], name: "index_claim_gen_payer_routes_on_organization_id"
    t.index ["payer_id"], name: "index_claim_gen_payer_routes_on_payer_id"
  end

  create_table "claim_lines", force: :cascade do |t|
    t.bigint "claim_id", null: false
    t.bigint "procedure_code_id", null: false
    t.integer "units", default: 1, null: false
    t.decimal "amount_billed", precision: 10, scale: 2, default: "0.0", null: false
    t.string "modifiers", default: [], array: true
    t.integer "dx_pointers_numeric", default: [], array: true
    t.string "place_of_service_code", null: false
    t.string "status", default: "generated", null: false
    t.string "adjudication_group_codes", default: [], array: true
    t.string "adjudication_carc_codes", default: [], array: true
    t.string "adjudication_rarc_codes", default: [], array: true
    t.decimal "adjudicated_amount", precision: 10, scale: 2
    t.decimal "balance_remaining", precision: 10, scale: 2, default: "0.0"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["claim_id"], name: "index_claim_lines_on_claim_id"
    t.index ["procedure_code_id"], name: "index_claim_lines_on_procedure_code_id"
  end

  create_table "claim_submissions", force: :cascade do |t|
    t.bigint "claim_id", null: false
    t.bigint "organization_id", null: false
    t.bigint "patient_id", null: false
    t.string "submission_method", default: "api", null: false
    t.datetime "submitted_at", precision: nil
    t.string "ack_status", default: "pending", null: false
    t.datetime "ack_received_at", precision: nil
    t.string "ack_code"
    t.text "error_message"
    t.string "resubmission_reason_code"
    t.string "external_submission_key"
    t.bigint "prior_submission_id"
    t.integer "status", default: 0, null: false
    t.string "edi_sha256"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "insurance_plan_id"
    t.index ["claim_id", "external_submission_key"], name: "idx_submission_external_per_claim", unique: true
    t.index ["claim_id"], name: "index_claim_submissions_on_claim_id"
    t.index ["insurance_plan_id"], name: "index_claim_submissions_on_insurance_plan_id"
    t.index ["organization_id"], name: "index_claim_submissions_on_organization_id"
    t.index ["patient_id"], name: "index_claim_submissions_on_patient_id"
    t.index ["prior_submission_id"], name: "index_claim_submissions_on_prior_submission_id"
    t.index ["submitted_at"], name: "index_claim_submissions_on_submitted_at"
  end

  create_table "claims", force: :cascade do |t|
    t.string "external_claim_key"
    t.bigint "organization_id", null: false
    t.bigint "encounter_id", null: false
    t.bigint "patient_id", null: false
    t.bigint "provider_id", null: false
    t.bigint "specialty_id", null: false
    t.integer "status"
    t.decimal "total_billed"
    t.integer "total_units"
    t.string "place_of_service_code"
    t.datetime "generated_at", precision: nil
    t.datetime "submitted_at", precision: nil
    t.datetime "accepted_at", precision: nil
    t.datetime "finalized_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "patient_insurance_coverage_id"
    t.index ["encounter_id"], name: "index_claims_on_encounter_id"
    t.index ["organization_id"], name: "index_claims_on_organization_id"
    t.index ["patient_id"], name: "index_claims_on_patient_id"
    t.index ["patient_insurance_coverage_id"], name: "index_claims_on_patient_insurance_coverage_id"
    t.index ["provider_id"], name: "index_claims_on_provider_id"
    t.index ["specialty_id"], name: "index_claims_on_specialty_id"
  end

  create_table "clinical_documentations", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "encounter_id", null: false
    t.bigint "patient_id", null: false
    t.bigint "author_provider_id", null: false
    t.bigint "signed_by_provider_id"
    t.bigint "cosigner_provider_id"
    t.integer "document_type", null: false
    t.jsonb "content_json", null: false
    t.integer "status", default: 0, null: false
    t.integer "version_seq", default: 1, null: false
    t.datetime "signed_at"
    t.datetime "cosigned_at"
    t.jsonb "section_locks"
    t.jsonb "assist_provenance"
    t.text "attestation_text"
    t.string "signature_hash", limit: 64
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_provider_id"], name: "index_clinical_documentations_on_author_provider_id"
    t.index ["cosigner_provider_id"], name: "index_clinical_documentations_on_cosigner_provider_id"
    t.index ["encounter_id"], name: "index_clinical_documentations_on_encounter_id"
    t.index ["organization_id"], name: "index_clinical_documentations_on_organization_id"
    t.index ["patient_id"], name: "index_clinical_documentations_on_patient_id"
    t.index ["signed_by_provider_id"], name: "index_clinical_documentations_on_signed_by_provider_id"
  end

  create_table "denial_items", force: :cascade do |t|
    t.bigint "denial_id", null: false
    t.bigint "claim_line_id", null: false
    t.decimal "amount_denied", precision: 10, scale: 2, default: "0.0", null: false
    t.string "carc_codes", default: [], array: true
    t.string "rarc_codes", default: [], array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["claim_line_id"], name: "index_denial_items_on_claim_line_id"
    t.index ["denial_id"], name: "index_denial_items_on_denial_id"
  end

  create_table "denials", force: :cascade do |t|
    t.bigint "claim_id", null: false
    t.bigint "organization_id", null: false
    t.bigint "patient_id", null: false
    t.bigint "encounter_id", null: false
    t.date "denial_date", null: false
    t.string "carc_codes", default: [], array: true
    t.string "rarc_codes", default: [], array: true
    t.decimal "amount_denied", precision: 10, scale: 2, default: "0.0", null: false
    t.bigint "source_submission_id", null: false
    t.integer "status", default: 0, null: false
    t.integer "attempt_count", default: 0, null: false
    t.boolean "tier_eligible", default: true, null: false
    t.text "notes_internal"
    t.string "source_hash"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["claim_id", "source_submission_id"], name: "idx_denial_one_per_submission", unique: true
    t.index ["claim_id"], name: "index_denials_on_claim_id"
    t.index ["organization_id"], name: "index_denials_on_organization_id"
    t.index ["source_hash"], name: "index_denials_on_source_hash", unique: true
    t.index ["source_submission_id"], name: "index_denials_on_source_submission_id"
  end

  create_table "diagnosis_codes", force: :cascade do |t|
    t.string "code"
    t.text "description"
    t.integer "status"
    t.datetime "effective_from"
    t.datetime "effective_to"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_diagnosis_codes_on_code", unique: true
    t.index ["status"], name: "index_diagnosis_codes_on_status"
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

  create_table "email_template_keys", force: :cascade do |t|
    t.string "key", null: false
    t.string "name", null: false
    t.string "description"
    t.string "default_subject", null: false
    t.text "default_body_html"
    t.text "default_body_text"
    t.string "default_locale", default: "en", null: false
    t.boolean "active", default: true, null: false
    t.datetime "last_used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_email_template_keys_on_key", unique: true
  end

  create_table "email_templates", force: :cascade do |t|
    t.bigint "email_template_key_id", null: false
    t.string "locale", default: "en", null: false
    t.string "subject"
    t.text "body_html"
    t.text "body_text"
    t.boolean "active", default: true, null: false
    t.bigint "created_by_id"
    t.bigint "updated_by_id"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_template_key_id", "locale"], name: "index_email_templates_on_key_and_locale", unique: true
    t.index ["email_template_key_id"], name: "index_email_templates_on_email_template_key_id"
  end

  create_table "encounter_comment_seens", force: :cascade do |t|
    t.bigint "encounter_id", null: false
    t.bigint "user_id", null: false
    t.datetime "last_seen_at", precision: nil, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["encounter_id", "user_id"], name: "index_encounter_comment_seens_on_encounter_id_and_user_id", unique: true
    t.index ["encounter_id"], name: "index_encounter_comment_seens_on_encounter_id"
    t.index ["user_id"], name: "index_encounter_comment_seens_on_user_id"
  end

  create_table "encounter_comments", force: :cascade do |t|
    t.bigint "encounter_id", null: false
    t.bigint "organization_id", null: false
    t.bigint "patient_id", null: false
    t.bigint "provider_id"
    t.integer "author_user_id", null: false
    t.integer "actor_type", null: false
    t.integer "visibility", default: 0, null: false
    t.text "body_text", null: false
    t.boolean "redacted", default: false, null: false
    t.integer "redaction_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_user_id"], name: "index_encounter_comments_on_author_user_id"
    t.index ["encounter_id", "created_at"], name: "index_encounter_comments_on_encounter_id_and_created_at"
    t.index ["encounter_id"], name: "index_encounter_comments_on_encounter_id"
    t.index ["organization_id", "visibility"], name: "index_encounter_comments_on_organization_id_and_visibility"
    t.index ["organization_id"], name: "index_encounter_comments_on_organization_id"
    t.index ["patient_id"], name: "index_encounter_comments_on_patient_id"
    t.index ["provider_id"], name: "index_encounter_comments_on_provider_id"
  end

  create_table "encounter_diagnosis_codes", force: :cascade do |t|
    t.bigint "diagnosis_code_id", null: false
    t.bigint "encounter_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["diagnosis_code_id"], name: "index_encounter_diagnosis_codes_on_diagnosis_code_id"
    t.index ["encounter_id"], name: "index_encounter_diagnosis_codes_on_encounter_id"
  end

  create_table "encounter_procedure_items", force: :cascade do |t|
    t.bigint "encounter_id", null: false
    t.bigint "procedure_code_id", null: false
    t.boolean "is_primary", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["encounter_id", "procedure_code_id"], name: "index_encounter_procedure_items_unique", unique: true
    t.index ["encounter_id"], name: "index_encounter_procedure_items_on_encounter_id"
    t.index ["is_primary"], name: "index_encounter_procedure_items_on_is_primary"
    t.index ["procedure_code_id"], name: "index_encounter_procedure_items_on_procedure_code_id"
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
    t.bigint "organization_location_id"
    t.bigint "appointment_id"
    t.integer "display_status", default: 0
    t.integer "billing_insurance_status", default: 0
    t.boolean "cascaded", default: false
    t.datetime "cascaded_at", precision: nil
    t.bigint "claim_id"
    t.bigint "patient_invoice_id"
    t.bigint "eligibility_check_used_id"
    t.datetime "confirmed_at", precision: nil
    t.bigint "confirmed_by_id"
    t.boolean "locked_for_correction", default: false
    t.datetime "discarded_at", precision: nil
    t.bigint "patient_insurance_coverage_id"
    t.index ["appointment_id"], name: "index_encounters_on_appointment_id"
    t.index ["cascaded"], name: "index_encounters_on_cascaded"
    t.index ["claim_id"], name: "index_encounters_on_claim_id"
    t.index ["confirmed_by_id"], name: "index_encounters_on_confirmed_by_id"
    t.index ["display_status"], name: "index_encounters_on_display_status"
    t.index ["eligibility_check_used_id"], name: "index_encounters_on_eligibility_check_used_id"
    t.index ["organization_id"], name: "index_encounters_on_organization_id"
    t.index ["organization_location_id"], name: "index_encounters_on_organization_location_id"
    t.index ["patient_id"], name: "index_encounters_on_patient_id"
    t.index ["patient_insurance_coverage_id"], name: "index_encounters_on_patient_insurance_coverage_id"
    t.index ["patient_invoice_id"], name: "index_encounters_on_patient_invoice_id"
    t.index ["provider_id"], name: "index_encounters_on_provider_id"
    t.index ["specialty_id"], name: "index_encounters_on_specialty_id"
  end

  create_table "insurance_plans", force: :cascade do |t|
    t.bigint "payer_id", null: false
    t.string "name", limit: 200, null: false
    t.integer "plan_type", null: false
    t.string "plan_code", limit: 100, null: false
    t.string "group_number_format"
    t.string "member_id_format"
    t.string "state_scope", default: [], array: true
    t.string "contact_url"
    t.text "notes_internal"
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["payer_id", "plan_code"], name: "idx_insurance_plans_payer_plan_code", unique: true
    t.index ["payer_id"], name: "index_insurance_plans_on_payer_id"
    t.index ["plan_type"], name: "index_insurance_plans_on_plan_type"
    t.index ["state_scope"], name: "index_insurance_plans_on_state_scope", using: :gin
    t.index ["status"], name: "index_insurance_plans_on_status"
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

  create_table "notifications", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "organization_id"
    t.string "notification_type", null: false
    t.string "title", null: false
    t.text "message", null: false
    t.string "action_url"
    t.boolean "read", default: false, null: false
    t.datetime "read_at", precision: nil
    t.jsonb "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["notification_type"], name: "index_notifications_on_notification_type"
    t.index ["organization_id"], name: "index_notifications_on_organization_id"
    t.index ["user_id", "created_at"], name: "index_notifications_on_user_id_and_created_at"
    t.index ["user_id", "read"], name: "index_notifications_on_user_id_and_read"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "org_accepted_plans", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "insurance_plan_id", null: false
    t.integer "status", default: 0, null: false
    t.integer "network_type", null: false
    t.integer "enrollment_status", default: 0, null: false
    t.date "effective_date", null: false
    t.date "end_date"
    t.bigint "added_by_id", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["added_by_id"], name: "index_org_accepted_plans_on_added_by_id"
    t.index ["enrollment_status"], name: "index_org_accepted_plans_on_enrollment_status"
    t.index ["insurance_plan_id"], name: "index_org_accepted_plans_on_insurance_plan_id"
    t.index ["network_type"], name: "index_org_accepted_plans_on_network_type"
    t.index ["organization_id", "insurance_plan_id"], name: "idx_org_accepted_plan_unique", unique: true
    t.index ["organization_id", "status"], name: "index_org_accepted_plans_on_organization_id_and_status"
    t.index ["organization_id"], name: "index_org_accepted_plans_on_organization_id"
    t.index ["status"], name: "index_org_accepted_plans_on_status"
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
    t.decimal "unit_price", precision: 10, scale: 2
    t.boolean "active", default: true, null: false
    t.boolean "locked", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "pricing_rule", default: 0, null: false
    t.index ["active"], name: "index_organization_fee_schedule_items_on_active"
    t.index ["locked"], name: "index_organization_fee_schedule_items_on_locked"
    t.index ["organization_fee_schedule_id", "procedure_code_id"], name: "index_fee_schedule_items_on_schedule_and_procedure", unique: true
    t.index ["organization_fee_schedule_id"], name: "idx_on_organization_fee_schedule_id_8245e30deb"
    t.index ["procedure_code_id"], name: "index_organization_fee_schedule_items_on_procedure_code_id"
  end

  create_table "organization_fee_schedule_specialties", force: :cascade do |t|
    t.bigint "organization_fee_schedule_id", null: false
    t.bigint "specialty_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_fee_schedule_id", "specialty_id"], name: "index_org_fee_schedule_specialties_unique", unique: true
    t.index ["organization_fee_schedule_id"], name: "idx_on_organization_fee_schedule_id_468ea506a8"
    t.index ["specialty_id"], name: "index_organization_fee_schedule_specialties_on_specialty_id"
  end

  create_table "organization_fee_schedules", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.string "name"
    t.integer "currency"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "discarded_at", precision: nil
    t.boolean "locked", default: false, null: false
    t.bigint "specialty_id"
    t.index ["discarded_at"], name: "index_organization_fee_schedules_on_discarded_at"
    t.index ["organization_id"], name: "index_organization_fee_schedules_on_organization_id"
    t.index ["specialty_id"], name: "index_organization_fee_schedules_on_specialty_id"
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
    t.integer "tax_id_type"
    t.integer "npi_type"
    t.index ["organization_id"], name: "index_organization_identifiers_on_organization_id"
  end

  create_table "organization_locations", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.string "name"
    t.integer "status"
    t.string "place_of_service_code"
    t.boolean "is_virtual"
    t.text "address_line_1"
    t.text "address_line_2"
    t.string "city"
    t.string "state"
    t.string "postal_code"
    t.string "country"
    t.string "phone_number"
    t.string "billing_npi"
    t.string "taxonomy_code"
    t.string "hours"
    t.text "notes_internal"
    t.datetime "discarded_at", precision: nil
    t.boolean "locked"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_organization_locations_on_organization_id"
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
    t.string "ezclaim_api_token"
    t.string "ezclaim_api_url", default: "https://ezclaimapiprod.azurewebsites.net/api/v2"
    t.string "ezclaim_api_version", default: "3.0.0"
    t.boolean "ezclaim_enabled", default: false
    t.index ["organization_id"], name: "index_organization_settings_on_organization_id"
  end

  create_table "organizations", force: :cascade do |t|
    t.string "name"
    t.string "subdomain"
    t.bigint "owner_id", null: false
    t.integer "activation_status"
    t.datetime "activation_state_changed_at", precision: nil
    t.datetime "closed_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "discarded_at"
    t.integer "tier", default: 0, null: false
    t.index ["discarded_at"], name: "index_organizations_on_discarded_at"
    t.index ["owner_id"], name: "index_organizations_on_owner_id"
  end

  create_table "patient_insurance_coverages", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "patient_id", null: false
    t.bigint "insurance_plan_id", null: false
    t.string "member_id", limit: 30, null: false
    t.string "subscriber_name", limit: 200, null: false
    t.jsonb "subscriber_address", default: {}, null: false
    t.integer "relationship_to_subscriber", null: false
    t.integer "coverage_order", default: 0, null: false
    t.date "effective_date"
    t.date "termination_date"
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["coverage_order"], name: "index_patient_insurance_coverages_on_coverage_order"
    t.index ["insurance_plan_id"], name: "index_patient_insurance_coverages_on_insurance_plan_id"
    t.index ["organization_id", "patient_id"], name: "idx_on_organization_id_patient_id_e712d5a003"
    t.index ["organization_id"], name: "index_patient_insurance_coverages_on_organization_id"
    t.index ["patient_id", "insurance_plan_id", "member_id"], name: "idx_coverage_patient_plan_member", unique: true
    t.index ["patient_id", "status", "coverage_order"], name: "idx_on_patient_id_status_coverage_order_5e67930726"
    t.index ["patient_id"], name: "index_patient_insurance_coverages_on_patient_id"
    t.index ["status"], name: "index_patient_insurance_coverages_on_status"
  end

  create_table "patients", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.string "first_name"
    t.string "last_name"
    t.date "dob"
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
    t.bigint "merged_into_patient_id"
    t.datetime "discarded_at", precision: nil
    t.index ["merged_into_patient_id"], name: "index_patients_on_merged_into_patient_id"
    t.index ["organization_id"], name: "index_patients_on_organization_id"
  end

  create_table "payer_enrollments", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "payer_id", null: false
    t.bigint "provider_id"
    t.bigint "organization_location_id"
    t.integer "enrollment_type", null: false
    t.integer "status", default: 0, null: false
    t.string "external_enrollment_id"
    t.datetime "submitted_at", precision: nil
    t.datetime "approved_at", precision: nil
    t.datetime "rejected_at", precision: nil
    t.datetime "cancelled_at", precision: nil
    t.text "cancellation_reason"
    t.integer "attempt_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["external_enrollment_id"], name: "index_payer_enrollments_on_external_enrollment_id"
    t.index ["organization_id", "payer_id", "enrollment_type", "provider_id", "organization_location_id"], name: "idx_payer_enrollments_unique_scope", unique: true, where: "(status = ANY (ARRAY[0, 1, 2, 3]))"
    t.index ["organization_id"], name: "index_payer_enrollments_on_organization_id"
    t.index ["organization_location_id"], name: "index_payer_enrollments_on_organization_location_id"
    t.index ["payer_id"], name: "index_payer_enrollments_on_payer_id"
    t.index ["provider_id"], name: "index_payer_enrollments_on_provider_id"
    t.index ["status"], name: "index_payer_enrollments_on_status"
  end

  create_table "payers", force: :cascade do |t|
    t.string "name"
    t.integer "payer_type"
    t.integer "id_namespace"
    t.integer "national_payer_id"
    t.string "contact_url"
    t.string "support_phone"
    t.text "notes_internal"
    t.string "state_scope", default: [], array: true
    t.integer "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "hbs_payer_key"
    t.text "search_tokens"
  end

  create_table "payment_applications", force: :cascade do |t|
    t.bigint "payment_id", null: false
    t.bigint "claim_id", null: false
    t.bigint "claim_line_id"
    t.decimal "amount_applied", precision: 10, scale: 2, default: "0.0", null: false
    t.bigint "patient_id", null: false
    t.bigint "encounter_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["claim_id", "claim_line_id"], name: "index_payment_applications_on_claim_id_and_claim_line_id"
    t.index ["claim_id"], name: "index_payment_applications_on_claim_id"
    t.index ["claim_line_id"], name: "index_payment_applications_on_claim_line_id"
    t.index ["payment_id"], name: "index_payment_applications_on_payment_id"
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
    t.bigint "payer_id"
    t.date "payment_date"
    t.decimal "amount_total", precision: 10, scale: 2
    t.string "remit_reference"
    t.string "source_hash"
    t.index ["invoice_id", "payment_status"], name: "index_payments_on_invoice_id_and_payment_status"
    t.index ["invoice_id"], name: "index_payments_on_invoice_id"
    t.index ["organization_id", "paid_at"], name: "index_payments_on_organization_id_and_paid_at"
    t.index ["organization_id", "payer_id", "remit_reference"], name: "idx_payments_org_payer_remit", unique: true
    t.index ["organization_id"], name: "index_payments_on_organization_id"
    t.index ["paid_at"], name: "index_payments_on_paid_at"
    t.index ["payer_id"], name: "index_payments_on_payer_id"
    t.index ["payment_provider_id"], name: "index_payments_on_payment_provider_id"
    t.index ["payment_status"], name: "index_payments_on_payment_status"
    t.index ["processed_by_user_id"], name: "index_payments_on_processed_by_user_id"
    t.index ["source_hash"], name: "index_payments_on_source_hash", unique: true
  end

  create_table "prescription_diagnosis_codes", force: :cascade do |t|
    t.bigint "prescription_id", null: false
    t.bigint "diagnosis_code_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["diagnosis_code_id"], name: "index_prescription_diagnosis_codes_on_diagnosis_code_id"
    t.index ["prescription_id", "diagnosis_code_id"], name: "index_prescription_diagnosis_codes_unique", unique: true
    t.index ["prescription_id"], name: "index_prescription_diagnosis_codes_on_prescription_id"
  end

  create_table "prescriptions", force: :cascade do |t|
    t.bigint "patient_id", null: false
    t.date "expires_on", null: false
    t.boolean "expired", default: false, null: false
    t.datetime "discarded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "title"
    t.bigint "organization_id", null: false
    t.date "date_written", null: false
    t.bigint "specialty_id"
    t.bigint "procedure_code_id"
    t.bigint "provider_id"
    t.boolean "archived", default: false, null: false
    t.datetime "archived_at"
    t.index ["archived"], name: "index_prescriptions_on_archived"
    t.index ["date_written"], name: "index_prescriptions_on_date_written"
    t.index ["discarded_at"], name: "index_prescriptions_on_discarded_at"
    t.index ["expired"], name: "index_prescriptions_on_expired"
    t.index ["expires_on"], name: "index_prescriptions_on_expires_on"
    t.index ["organization_id"], name: "index_prescriptions_on_organization_id"
    t.index ["patient_id"], name: "index_prescriptions_on_patient_id"
    t.index ["procedure_code_id"], name: "index_prescriptions_on_procedure_code_id"
    t.index ["provider_id"], name: "index_prescriptions_on_provider_id"
    t.index ["specialty_id"], name: "index_prescriptions_on_specialty_id"
  end

  create_table "procedure_code_rules", force: :cascade do |t|
    t.bigint "procedure_code_id", null: false
    t.boolean "time_based", default: false
    t.string "pricing_type"
    t.jsonb "special_rules", default: []
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["procedure_code_id"], name: "index_procedure_code_rules_on_procedure_code_id", unique: true
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

  create_table "provider_notes", force: :cascade do |t|
    t.bigint "encounter_id", null: false
    t.bigint "provider_id", null: false
    t.text "note_text"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["encounter_id"], name: "index_provider_notes_on_encounter_id"
    t.index ["provider_id"], name: "index_provider_notes_on_provider_id"
  end

  create_table "providers", force: :cascade do |t|
    t.string "first_name", limit: 100, null: false
    t.string "last_name", limit: 100, null: false
    t.string "npi", limit: 10
    t.string "license_number"
    t.string "license_state", limit: 2
    t.bigint "user_id"
    t.string "status", default: "draft", null: false
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "discarded_at"
    t.bigint "specialty_id"
    t.index ["discarded_at"], name: "index_providers_on_discarded_at"
    t.index ["npi"], name: "index_providers_on_npi", unique: true, where: "(npi IS NOT NULL)"
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

  create_table "support_ticket_comments", force: :cascade do |t|
    t.bigint "support_ticket_id", null: false
    t.bigint "author_user_id", null: false
    t.integer "visibility", default: 0, null: false
    t.text "body", null: false
    t.boolean "system_generated", default: false, null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_user_id"], name: "index_support_ticket_comments_on_author_user_id"
    t.index ["created_at"], name: "index_support_ticket_comments_on_created_at"
    t.index ["support_ticket_id"], name: "index_support_ticket_comments_on_support_ticket_id"
    t.index ["visibility"], name: "index_support_ticket_comments_on_visibility"
  end

  create_table "support_ticket_tasks", force: :cascade do |t|
    t.bigint "support_ticket_id", null: false
    t.integer "task_type", null: false
    t.integer "status", default: 0, null: false
    t.datetime "opened_at", null: false
    t.datetime "completed_at"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_support_ticket_tasks_on_status"
    t.index ["support_ticket_id", "task_type"], name: "index_support_ticket_tasks_on_ticket_and_type"
    t.index ["support_ticket_id"], name: "index_support_ticket_tasks_on_support_ticket_id"
  end

  create_table "support_tickets", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "created_by_user_id", null: false
    t.bigint "assigned_to_user_id"
    t.integer "category", null: false
    t.string "subject", limit: 200, null: false
    t.text "description", null: false
    t.integer "priority", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.string "linked_resource_type"
    t.string "linked_resource_id"
    t.uuid "attachments", default: [], array: true
    t.jsonb "internal_notes", default: [], null: false
    t.datetime "first_response_due_at", null: false
    t.datetime "resolution_due_at", null: false
    t.datetime "closed_at"
    t.datetime "discarded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assigned_to_user_id"], name: "index_support_tickets_on_assigned_to_user_id"
    t.index ["category"], name: "index_support_tickets_on_category"
    t.index ["created_by_user_id"], name: "index_support_tickets_on_created_by_user_id"
    t.index ["discarded_at"], name: "index_support_tickets_on_discarded_at"
    t.index ["first_response_due_at"], name: "index_support_tickets_on_first_response_due_at"
    t.index ["linked_resource_type", "linked_resource_id"], name: "index_support_tickets_on_linked_resource"
    t.index ["organization_id"], name: "index_support_tickets_on_organization_id"
    t.index ["priority"], name: "index_support_tickets_on_priority"
    t.index ["resolution_due_at"], name: "index_support_tickets_on_resolution_due_at"
    t.index ["status"], name: "index_support_tickets_on_status"
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

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "appointments", "organization_locations"
  add_foreign_key "appointments", "organizations"
  add_foreign_key "appointments", "patients"
  add_foreign_key "appointments", "providers"
  add_foreign_key "appointments", "specialties"
  add_foreign_key "claim_gen_payer_routes", "organizations"
  add_foreign_key "claim_gen_payer_routes", "payers"
  add_foreign_key "claim_lines", "claims"
  add_foreign_key "claim_lines", "procedure_codes"
  add_foreign_key "claim_submissions", "claim_submissions", column: "prior_submission_id"
  add_foreign_key "claim_submissions", "claims"
  add_foreign_key "claim_submissions", "insurance_plans"
  add_foreign_key "claim_submissions", "organizations"
  add_foreign_key "claim_submissions", "patients"
  add_foreign_key "claims", "encounters"
  add_foreign_key "claims", "organizations"
  add_foreign_key "claims", "patient_insurance_coverages"
  add_foreign_key "claims", "patients"
  add_foreign_key "claims", "providers"
  add_foreign_key "claims", "specialties"
  add_foreign_key "clinical_documentations", "encounters"
  add_foreign_key "clinical_documentations", "organizations"
  add_foreign_key "clinical_documentations", "patients"
  add_foreign_key "clinical_documentations", "providers", column: "author_provider_id"
  add_foreign_key "clinical_documentations", "providers", column: "cosigner_provider_id"
  add_foreign_key "clinical_documentations", "providers", column: "signed_by_provider_id"
  add_foreign_key "denial_items", "claim_lines"
  add_foreign_key "denial_items", "denials"
  add_foreign_key "denials", "claim_submissions", column: "source_submission_id"
  add_foreign_key "denials", "claims"
  add_foreign_key "denials", "organizations"
  add_foreign_key "document_attachments", "documents"
  add_foreign_key "document_attachments", "users", column: "uploaded_by_id"
  add_foreign_key "documents", "organizations"
  add_foreign_key "documents", "users", column: "created_by_id"
  add_foreign_key "email_templates", "email_template_keys"
  add_foreign_key "email_templates", "users", column: "created_by_id"
  add_foreign_key "email_templates", "users", column: "updated_by_id"
  add_foreign_key "encounter_comment_seens", "encounters"
  add_foreign_key "encounter_comment_seens", "users"
  add_foreign_key "encounter_comments", "encounters"
  add_foreign_key "encounter_comments", "organizations"
  add_foreign_key "encounter_comments", "patients"
  add_foreign_key "encounter_comments", "providers"
  add_foreign_key "encounter_comments", "users", column: "author_user_id"
  add_foreign_key "encounter_diagnosis_codes", "diagnosis_codes"
  add_foreign_key "encounter_diagnosis_codes", "encounters"
  add_foreign_key "encounter_procedure_items", "encounters"
  add_foreign_key "encounter_procedure_items", "procedure_codes"
  add_foreign_key "encounters", "appointments"
  add_foreign_key "encounters", "organization_locations"
  add_foreign_key "encounters", "organizations"
  add_foreign_key "encounters", "patient_insurance_coverages"
  add_foreign_key "encounters", "patients"
  add_foreign_key "encounters", "providers"
  add_foreign_key "encounters", "specialties"
  add_foreign_key "insurance_plans", "payers"
  add_foreign_key "invoice_line_items", "invoices"
  add_foreign_key "invoices", "organizations"
  add_foreign_key "invoices", "users", column: "exception_set_by_user_id"
  add_foreign_key "notifications", "organizations"
  add_foreign_key "notifications", "users"
  add_foreign_key "org_accepted_plans", "insurance_plans"
  add_foreign_key "org_accepted_plans", "organizations"
  add_foreign_key "org_accepted_plans", "users", column: "added_by_id"
  add_foreign_key "organization_billings", "organizations"
  add_foreign_key "organization_compliances", "organizations"
  add_foreign_key "organization_contacts", "organizations"
  add_foreign_key "organization_fee_schedule_items", "organization_fee_schedules"
  add_foreign_key "organization_fee_schedule_items", "procedure_codes"
  add_foreign_key "organization_fee_schedule_specialties", "organization_fee_schedules"
  add_foreign_key "organization_fee_schedule_specialties", "specialties"
  add_foreign_key "organization_fee_schedules", "organizations"
  add_foreign_key "organization_fee_schedules", "specialties"
  add_foreign_key "organization_identifiers", "organizations"
  add_foreign_key "organization_locations", "organizations"
  add_foreign_key "organization_memberships", "organizations"
  add_foreign_key "organization_memberships", "roles", column: "organization_role_id"
  add_foreign_key "organization_memberships", "users"
  add_foreign_key "organization_settings", "organizations"
  add_foreign_key "organizations", "users", column: "owner_id"
  add_foreign_key "patient_insurance_coverages", "insurance_plans"
  add_foreign_key "patient_insurance_coverages", "organizations"
  add_foreign_key "patient_insurance_coverages", "patients"
  add_foreign_key "patients", "organizations"
  add_foreign_key "patients", "patients", column: "merged_into_patient_id"
  add_foreign_key "payer_enrollments", "organization_locations"
  add_foreign_key "payer_enrollments", "organizations"
  add_foreign_key "payer_enrollments", "payers"
  add_foreign_key "payer_enrollments", "providers"
  add_foreign_key "payment_applications", "claim_lines"
  add_foreign_key "payment_applications", "claims"
  add_foreign_key "payment_applications", "payments"
  add_foreign_key "payments", "invoices"
  add_foreign_key "payments", "organizations"
  add_foreign_key "payments", "payers"
  add_foreign_key "payments", "users", column: "processed_by_user_id"
  add_foreign_key "prescription_diagnosis_codes", "diagnosis_codes"
  add_foreign_key "prescription_diagnosis_codes", "prescriptions"
  add_foreign_key "prescriptions", "organizations"
  add_foreign_key "prescriptions", "procedure_codes"
  add_foreign_key "prescriptions", "providers"
  add_foreign_key "prescriptions", "specialties"
  add_foreign_key "procedure_code_rules", "procedure_codes"
  add_foreign_key "procedure_codes_specialties", "procedure_codes"
  add_foreign_key "procedure_codes_specialties", "specialties"
  add_foreign_key "provider_assignments", "organizations"
  add_foreign_key "provider_assignments", "providers"
  add_foreign_key "provider_notes", "encounters"
  add_foreign_key "provider_notes", "providers"
  add_foreign_key "providers", "specialties"
  add_foreign_key "providers", "users"
  add_foreign_key "support_ticket_comments", "support_tickets"
  add_foreign_key "support_ticket_comments", "users", column: "author_user_id"
  add_foreign_key "support_ticket_tasks", "support_tickets"
  add_foreign_key "support_tickets", "organizations"
  add_foreign_key "support_tickets", "users", column: "assigned_to_user_id"
  add_foreign_key "support_tickets", "users", column: "created_by_user_id"
  add_foreign_key "users", "roles"
end

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

ActiveRecord::Schema[7.2].define(version: 2025_10_16_093619) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

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

  add_foreign_key "organization_billings", "organizations"
  add_foreign_key "organization_compliances", "organizations"
  add_foreign_key "organization_contacts", "organizations"
  add_foreign_key "organization_identifiers", "organizations"
  add_foreign_key "organization_memberships", "organizations"
  add_foreign_key "organization_memberships", "roles", column: "organization_role_id"
  add_foreign_key "organization_memberships", "users"
  add_foreign_key "organization_settings", "organizations"
  add_foreign_key "organizations", "users", column: "owner_id"
  add_foreign_key "roles", "organizations"
  add_foreign_key "users", "roles"
end

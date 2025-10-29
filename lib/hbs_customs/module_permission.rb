# frozen_string_literal: true

module HbsCustoms
  class ModulePermission
    DEFAULT_CRUD = {
      index: false,
      show: false,
      edit: false,
      create: false,
      update: false,
      destroy: false
    }.freeze

    DEFAULT_CRUD_WITH_STATE = DEFAULT_CRUD.merge(
      activate: false,
      inactivate: false,
      reactivate: false
    ).freeze

    DEFAULT_CRUD_WITH_RETIRE = DEFAULT_CRUD.merge(
      retire: false,
      activate: false
    ).freeze

    DEFAULT_CRUD_WITH_WORKFLOW = DEFAULT_CRUD.merge(
      confirm_completed: false,
      cancel: false,
      request_correction: false
    ).freeze

    class << self
      def data
        {
          tenant: tenant_permissions,
          admin: admin_permissions
        }
      end

      def admin_access
        update_all_to_true(data)
      end

      def tenant_admin_access
        tenant_data = data.deep_dup
        tenant_data[:tenant] = update_all_to_true(tenant_data[:tenant])
        tenant_data
      end

      private

      def tenant_permissions
        {
          dashboard: { index: false },
          invoices: DEFAULT_CRUD,
          activation: DEFAULT_CRUD,
          stripe: { setup_intent: false, confirm_card: false },
          gocardless: { create_redirect_flow: false },
          providers: DEFAULT_CRUD.except(:destroy),
          specialties: DEFAULT_CRUD,
          diagnoses_codes: DEFAULT_CRUD_WITH_RETIRE,
          fee_schedules: DEFAULT_CRUD,
          fee_schedule_items: DEFAULT_CRUD,
          procedure_codes: DEFAULT_CRUD,
          organization_locations: DEFAULT_CRUD_WITH_STATE,
          appointments: DEFAULT_CRUD_WITH_STATE,
          organization_settings: { show: false, edit: false, update: false },
          encounters: DEFAULT_CRUD_WITH_WORKFLOW,
          patients: DEFAULT_CRUD
        }
      end

      def admin_permissions
        {
          dashboard: { index: false },
          organizations: DEFAULT_CRUD,
          users: DEFAULT_CRUD,
          roles: DEFAULT_CRUD,
          organization_billings: DEFAULT_CRUD,
          invoices: DEFAULT_CRUD,
          providers: DEFAULT_CRUD,
          specialties: DEFAULT_CRUD,
          diagnoses_codes: DEFAULT_CRUD_WITH_RETIRE,
          documents: DEFAULT_CRUD,
          payments: DEFAULT_CRUD,
          fee_schedules: DEFAULT_CRUD,
          fee_schedule_items: DEFAULT_CRUD,
          procedure_codes: DEFAULT_CRUD,
          organization_locations: DEFAULT_CRUD_WITH_STATE.except(:create),
          appointments: DEFAULT_CRUD_WITH_STATE.except(:create, :destroy),
          audits: { index: false, show: false, model_audits: false },
          encounters: DEFAULT_CRUD_WITH_WORKFLOW.merge(override_validation: false),
          patients: DEFAULT_CRUD
        }
      end

      def update_all_to_true(hash)
        hash.transform_values do |v|
          case v
          when Hash
            update_all_to_true(v)
          else
            true
          end
        end
      end
    end
  end
end

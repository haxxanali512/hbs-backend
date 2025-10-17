module HbsCustoms
class ModulePermission
  class << self
    def data
      {
        users_management_module: {
          invitations: crud_actions,
          users: crud_actions,
          roles: crud_actions,
          dashboard: crud_actions,
          invoices: crud_actions
        },
        organization_management_module: {
          organizations: crud_actions,
          activation: crud_actions,
          billing: crud_actions,
          compliance: crud_actions
        },
        medical_billing_module: {
          patients: crud_actions,
          claims: crud_actions.merge({ submit: false, appeal: false }),
          invoices: crud_actions.merge({ send: false, void: false }),
          payments: crud_actions.merge({ refund: false }),
          reports: { view_financial: false, view_clinical: false, export: false }
        },
        tenant_management_module: {
          team_members: crud_actions,
          departments: crud_actions,
          settings: { view: false, update: false }
        },
        tenant_dashboard_module: {
          dashboard: crud_actions,
          # patients: crud_actions,
          # claims: crud_actions,
          invoices: crud_actions
        }
      }
    end

    def full_access
      update_val_to_true(data)
    end

    def global_admin_access
      global_data = data.dup
      # Global admins get full access to user management and organization management
      global_data[:users_management_module] = update_val_to_true(global_data[:users_management_module])
      global_data[:organization_management_module] = update_val_to_true(global_data[:organization_management_module])
      global_data
    end

    def tenant_admin_access
      tenant_data = data.dup
      # Tenant admins get full access to medical billing and tenant management
      tenant_data[:medical_billing_module] = update_val_to_true(tenant_data[:medical_billing_module])
      tenant_data[:tenant_management_module] = update_val_to_true(tenant_data[:tenant_management_module])
      tenant_data
    end

    def billing_manager_access
      billing_data = data.dup
      # Billing managers get limited access to medical billing
      billing_data[:medical_billing_module][:patients] = { index: true, show: true, create: false, update: false, destroy: false }
      billing_data[:medical_billing_module][:claims] = { index: true, show: true, create: true, update: true, submit: true, appeal: false, destroy: false }
      billing_data[:medical_billing_module][:invoices] = { index: true, show: true, create: true, update: true, send: true, void: true, destroy: false }
      billing_data[:medical_billing_module][:payments] = { index: true, show: true, create: true, update: true, refund: true, destroy: false }
      billing_data[:medical_billing_module][:reports] = { view_financial: true, view_clinical: false, export: true }
      billing_data
    end

    def clinical_staff_access
      clinical_data = data.dup
      # Clinical staff get read-only access to patients and claims
      clinical_data[:medical_billing_module][:patients] = { index: true, show: true, create: false, update: false, destroy: false }
      clinical_data[:medical_billing_module][:claims] = { index: true, show: true, create: false, update: false, submit: false, appeal: false, destroy: false }
      clinical_data[:medical_billing_module][:invoices] = { index: false, show: false, create: false, update: false, send: false, void: false, destroy: false }
      clinical_data[:medical_billing_module][:payments] = { index: false, show: false, create: false, update: false, refund: false, destroy: false }
      clinical_data[:medical_billing_module][:reports] = { view_financial: false, view_clinical: true, export: false }
      clinical_data
    end

    private

    def crud_actions
      {
        index: false,
        show: false,
        create: false,
        update: false,
        destroy: false
      }
    end

    def update_val_to_true(hash)
      hash.each do |key, val|
        case val
        when Hash
          update_val_to_true val
        when Array
          val.flatten.each { |v| update_val_to_true(v) if v.is_a?(Hash) }
        when FalseClass
          hash[key] = true
        end
        hash
      end
    end
  end
end
end

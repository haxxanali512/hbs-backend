module HbsCustoms
  class ModulePermission
    class << self
      def data
        {
          tenant: {
            dashboard: {
              index: false
            },
            invoices: {
              index: false,
              show: false,
              edit: false,
              create: false,
              update: false,
              destroy: false
            },
            activation: {
              index: false,
              show: false,
              edit: false,
              create: false,
              update: false,
              destroy: false
            },
            stripe: {
              setup_intent: false,
              confirm_card: false
            },
            gocardless: {
              create_redirect_flow: false
            },
            providers: {
              index: false,
              show: false,
              edit: false,
              update: false,
              create: false
            }
          },
          admin: {
            dashboard: {
              index: false
            },
            organizations: {
              index: false,
              show: false,
              edit: false,
              create: false,
              update: false,
              destroy: false
            },
            users: {
              index: false,
              show: false,
              edit: false,
              create: false,
              update: false,
              destroy: false
            },
            roles: {
              index: false,
              show: false,
              edit: false,
              create: false,
              update: false,
              destroy: false
            },
            organization_billings: {
              index: false,
              show: false,
              edit: false,
              create: false,
              update: false,
              destroy: false
            },
            invoices: {
              index: false,
              show: false,
              edit: false,
              create: false,
              update: false,
              destroy: false
            }
          }
        }
      end

      # Give full access to tenant admin and admin roles
      def admin_access
        update_all_to_true(data)
      end

      # Give full access to tenant admin only
      def tenant_admin_access
        tenant_data = data.dup
        tenant_data[:tenant] = update_all_to_true(tenant_data[:tenant])
        tenant_data
      end

      private

      def update_all_to_true(hash)
        hash.each do |key, value|
          case value
          when Hash
            hash[key] = update_all_to_true(value)
          when FalseClass
            hash[key] = true
          end
        end
        hash
      end
    end
  end
end

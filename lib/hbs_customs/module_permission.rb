module HbsCustoms
class ModulePermission
  class << self
    def data
      {
        users_management_module: {
          invitations: crud_actions,
          users: crud_actions,
          roles: crud_actions,
          dashboard: crud_actions
        }
      }
    end

    def full_access
      update_val_to_true(data)
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

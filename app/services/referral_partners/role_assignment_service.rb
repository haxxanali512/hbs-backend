module ReferralPartners
  class RoleAssignmentService
    def self.call(user:)
      new(user:).call
    end

    def initialize(user:)
      @user = user
    end

    def call
      return user.role if user.has_referral_partner_access?

      user.update!(role: referral_ready_role)
      user.role
    end

    private

    attr_reader :user

    def referral_ready_role
      return referral_partner_role unless user.role.present?

      merged_access = HbsCustoms::ModulePermission.data.deep_stringify_keys.deep_merge(user.role.access.deep_stringify_keys)
      merged_access["referral_partner"] = HbsCustoms::ModulePermission.admin_access.deep_stringify_keys.fetch("referral_partner", {})

      role_name = "#{user.role.role_name} + Referral Partner"
      Role.find_or_create_by!(role_name:, scope: user.role.scope) do |role|
        role.access = merged_access
      end
    end

    def referral_partner_role
      Role.find_or_create_by!(role_name: "Referral Partner User", scope: :tenant) do |role|
        access = HbsCustoms::ModulePermission.data.deep_dup.deep_stringify_keys
        access["referral_partner"] = HbsCustoms::ModulePermission.admin_access.deep_stringify_keys.fetch("referral_partner", {})
        role.access = access
      end
    end
  end
end

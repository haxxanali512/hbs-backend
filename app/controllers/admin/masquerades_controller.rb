module Admin
  class MasqueradesController < Devise::MasqueradesController
    def show
      # First check if current user is an admin
      unless current_user&.hbs_user?
        redirect_to admin_users_path, alert: "You don't have permission to impersonate users."
        return
      end

      # Find the target user from the masquerade token
      target_user = find_masqueradable_resource

      unless target_user
        redirect_to admin_users_path, alert: "User not found."
        return
      end

      # Check if the target user is a tenant user (not an admin)
      if target_user.hbs_user?
        redirect_to admin_users_path, alert: "You can only impersonate tenant users."
        return
      end

      # Use Pundit authorization if available
      unless current_user.permissions_for("admin", "users", "masquerade")
        redirect_to admin_users_path, alert: "You don't have permission to impersonate users."
        return
      end

      # Call parent to proceed with masquerade
      super
    end

    protected

    def masquerade_authorize!
      # Only allow admins to masquerade as tenant users
      unless current_user&.hbs_user?
        redirect_to admin_users_path, alert: "You don't have permission to impersonate users."
        nil
      end
      # Note: We can't check if target user is tenant here because
      # the user hasn't been found yet (devise_masquerade uses tokens, not IDs)
      # We'll check this in the show method after the user is found
    end

    def after_masquerade_path_for(resource)
      tenant_dashboard_path
    end

    def after_back_masquerade_path_for(resource)
      admin_users_path
    end
  end
end

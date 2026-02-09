module Admin
  class MasqueradesController < Devise::MasqueradesController
    # Override authenticate_user! to skip on tenant subdomains
    def authenticate_user!(*args)
      return if on_tenant_subdomain?
      super
    end

    # Override has_access? to skip on tenant subdomains
    def has_access?
      return true if on_tenant_subdomain?
      super
    end

    # Override back so that on tenant subdomain (where we have no stored original user)
    # we sign out and redirect to admin portal instead of failing.
    def back
      if on_tenant_subdomain? && session[:devise_masquerade_user_id].blank?
        Rails.logger.info "Masquerade: Stopping impersonation on tenant subdomain, redirecting to admin"
        sign_out(current_user) if current_user.present?
        url = admin_portal_url
        url += (url.include?("?") ? "&" : "?") + "impersonation_ended=1"
        redirect_to url, allow_other_host: true
        return
      end
      super
    end

    def show
      # Check if we're on a tenant subdomain (cross-subdomain redirect scenario)
      # In this case, we need to process the masquerade manually since there's no session
      if on_tenant_subdomain?
        Rails.logger.info "Masquerade: Processing on tenant subdomain manually"

        # Find the target user from the masquerade token
        target_user = find_masqueradable_resource

        unless target_user
          redirect_to new_user_session_path, alert: "Invalid masquerade token."
          return
        end

        # Sign in as the target user (bypass authentication since we're using a token)
        sign_in(target_user, bypass: true)

        # Set up masquerade session variables
        # Note: We can't store the original admin user ID in session since sessions don't share across subdomains
        # The masquerade will work, but "back" functionality won't work across subdomains
        session[:devise_masquerade_user_id] = nil # Can't store admin user ID across subdomains
        session[:devise_masquerade_masquerading_resource_class] = target_user.class.name

        # Redirect to tenant dashboard
        redirect_url = after_masquerade_path_for(target_user)
        Rails.logger.info "Masquerade: Redirecting to #{redirect_url}"
        redirect_to redirect_url
        return
      end

      # We're on the admin subdomain - perform authorization checks
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

      # Store the original admin user
      original_user = current_user

      # Get the masquerade token from the URL so we can pass it to the tenant subdomain
      masquerade_token = params[:masquerade]
      masqueraded_resource_class = params[:masqueraded_resource_class] || target_user.class.name

      # Get redirect URL with subdomain and append masquerade token
      redirect_url = after_masquerade_path_for(target_user, masquerade_token, masqueraded_resource_class)

      Rails.logger.info "Masquerade: Original user: #{original_user.id}, Target user: #{target_user.id}, Token: #{masquerade_token}, Redirect URL: #{redirect_url}"

      # Redirect with allow_other_host to support subdomain redirects
      # The masquerade token in the URL will allow devise_masquerade to process it on the tenant subdomain
      redirect_to redirect_url, allow_other_host: true
    end

    protected

    def on_tenant_subdomain?
      # Check if we're on a tenant subdomain (not admin or www)
      subdomain = request.subdomain
      return false if subdomain.blank?
      return false if subdomain == "admin" || subdomain == "www"

      # In development, check if host contains a subdomain before .hbs.localhost
      if Rails.env.development?
        host = request.host
        # Check if host matches pattern: {subdomain}.hbs.localhost
        host.match?(/^[^.]+\.hbs\.localhost/)
      else
        # In production, if there's a subdomain and it's not admin/www, it's a tenant
        true
      end
    end

    def masquerade_authorize!
      # If we're on a tenant subdomain, skip authorization
      # The authorization was already done on the admin subdomain
      # and the masquerade token is being processed here
      if on_tenant_subdomain?
        Rails.logger.info "Masquerade: Skipping authorization on tenant subdomain"
        return true
      end

      # Only allow admins to masquerade as tenant users
      unless current_user&.hbs_user?
        redirect_to admin_users_path, alert: "You don't have permission to impersonate users."
        nil
      end
      # Note: We can't check if target user is tenant here because
      # the user hasn't been found yet (devise_masquerade uses tokens, not IDs)
      # We'll check this in the show method after the user is found
    end

    def after_masquerade_path_for(resource, *args)
      Rails.logger.info "Masquerade: after_masquerade_path_for called - Resource: #{resource.id}, Args: #{args.inspect}, On tenant subdomain: #{on_tenant_subdomain?}, Host: #{request.host}"

      # If we're on a tenant subdomain, redirect to tenant dashboard
      if on_tenant_subdomain?
        path = "/tenant/dashboard"
        Rails.logger.info "Masquerade: Redirecting to tenant dashboard: #{path}"
        return path
      end

      # We're on the admin subdomain - redirect to tenant subdomain with masquerade token
      # Get the target user's organization
      organization = resource.active_organizations.first || resource.organizations.first

      unless organization
        # Fallback: build admin URL (shouldn't happen, but just in case)
        Rails.logger.warn "No organization found for user #{resource.id} during masquerade"
        return "#{request.protocol}#{request.host_with_port}/tenant/dashboard"
      end

      # Build tenant URL with subdomain
      if Rails.env.development?
        # Development: {subdomain}.hbs.localhost:3000
        tenant_url = "#{request.protocol}#{organization.subdomain}.hbs.localhost:3000"
      else
        # Production: {subdomain}.{request.host}
        # Extract base host (remove any existing subdomain like 'admin' or 'www')
        host_parts = request.host.split(".")
        # If host has more than 2 parts (e.g., admin.example.com), remove the first part
        base_host = host_parts.length > 2 ? host_parts.drop(1).join(".") : request.host
        # Include port if present and not standard
        base_host = "#{base_host}:#{request.port}" if request.port != 80 && request.port != 443
        tenant_url = "#{request.protocol}#{organization.subdomain}.#{base_host}"
      end

      # Get masquerade token from params if available (for admin subdomain redirect)
      masquerade_token = params[:masquerade] || args[0]
      masqueraded_resource_class = params[:masqueraded_resource_class] || args[1] || resource.class.name

      # Build the masquerade URL on the tenant subdomain
      # This allows devise_masquerade to process the masquerade on the tenant subdomain
      # After processing, devise_masquerade will redirect to the dashboard via after_masquerade_path_for
      if masquerade_token.present?
        uri = URI.parse("#{tenant_url}/users/masquerade")
        query_params = URI.decode_www_form(uri.query || "")
        query_params << [ "masquerade", masquerade_token ]
        query_params << [ "masqueraded_resource_class", masqueraded_resource_class ] if masqueraded_resource_class.present?
        uri.query = URI.encode_www_form(query_params)
        full_url = uri.to_s
      else
        # Fallback if no token (shouldn't happen)
        full_url = "#{tenant_url}/tenant/dashboard"
      end

      Rails.logger.info "Masquerade redirect URL: #{full_url}"
      full_url
    end

    def after_back_masquerade_path_for(resource)
      admin_users_path
    end

    # Full URL for the admin portal (used when stopping impersonation from tenant subdomain)
    def admin_portal_url
      if Rails.env.development?
        port = request.port || 3000
        # Match tenant URL pattern: tenant is at subdomain.hbs.localhost, so admin is at admin.hbs.localhost
        base = request.host.include?("hbs.localhost") ? "admin.hbs.localhost" : "admin.localhost"
        "#{request.protocol}#{base}:#{port}"
      else
        # Production: admin subdomain on the same base domain as tenant
        host_parts = request.host.split(".")
        base_host = host_parts.length > 2 ? host_parts.drop(1).join(".") : request.host
        base_host = "#{base_host}:#{request.port}" if request.port.present? && request.port != 80 && request.port != 443
        "#{request.protocol}admin.#{base_host}"
      end
    end
  end
end

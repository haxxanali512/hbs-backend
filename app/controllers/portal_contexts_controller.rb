class PortalContextsController < ApplicationController
  skip_before_action :has_access?

  def switch
    destination = portal_destination_for(params[:context].to_s)

    if destination.present?
      redirect_to destination, allow_other_host: true
    else
      redirect_back fallback_location: root_path, alert: "That portal context is not available for your account."
    end
  end
end

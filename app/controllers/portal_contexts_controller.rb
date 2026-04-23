class PortalContextsController < ApplicationController
  skip_before_action :has_access?

  def index
    @contexts = available_portal_contexts
  end

  def update
    context = params[:context].to_s.presence&.to_sym

    unless available_portal_contexts.include?(context)
      redirect_to portal_contexts_path, alert: "That portal is not available for your account."
      return
    end

    session[:portal_context] = context.to_s
    redirect_to portal_context_path_for(context), allow_other_host: true
  end
end

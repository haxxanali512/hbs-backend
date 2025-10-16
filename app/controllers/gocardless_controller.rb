class GocardlessController < ApplicationController
  before_action :authenticate_user!
  before_action :set_current_organization

  def create_redirect_flow
    begin
      Rails.logger.info "Creating GoCardless redirect flow for organization #{@current_organization.id}"
      gocardless_service = GocardlessService.new

      # Create redirect flow with customer details
      redirect_params = {
        description: "Billing setup for #{@current_organization.name}",
        session_token: SecureRandom.uuid,
        success_redirect_url: "#{request.base_url}/gocardless/redirect_flow/complete",
        given_name: params[:given_name],
        family_name: params[:family_name],
        email: params[:email],
        address_line1: params[:address_line1],
        city: params[:city],
        postal_code: params[:postal_code],
        country_code: params[:country_code],
        metadata: {
          organization_id: @current_organization.id.to_s,
          user_id: current_user.id.to_s
        }
      }

      Rails.logger.info "GoCardless redirect params: #{redirect_params.inspect}"
      result = gocardless_service.create_redirect_flow(redirect_params)

      if result[:success]
        # Store redirect flow ID and session token in session for completion
        session[:gocardless_redirect_flow_id] = result[:redirect_flow][:id]
        session[:gocardless_session_token] = result[:redirect_flow][:session_token]

        render json: {
          success: true,
          redirect_url: result[:redirect_flow][:redirect_url]
        }
      else
        render json: {
          success: false,
          error: result[:error]
        }, status: :unprocessable_entity
      end
    rescue => e
      Rails.logger.error "GoCardless redirect flow error: #{e.message}"
      render json: {
        success: false,
        error: "Failed to create authorization flow. Please try again."
      }, status: :internal_server_error
    end
  end

  def complete_redirect_flow
    redirect_flow_id = session[:gocardless_redirect_flow_id]
    session_token = session[:gocardless_session_token]

    unless redirect_flow_id
      redirect_to tenant_activation_billing_path, alert: "No authorization session found. Please try again."
      return
    end

    begin
      Rails.logger.info "Completing GoCardless redirect flow for organization #{@current_organization.id}"
      Rails.logger.info "Using session token: #{session_token.present? ? 'present' : 'missing'}"
      gocardless_service = GocardlessService.new

      # Complete the redirect flow
      result = gocardless_service.complete_redirect_flow(redirect_flow_id, session_token: session_token)
      Rails.logger.info "GoCardless completion result: #{result.inspect}"

      if result[:success]
        redirect_flow = result[:redirect_flow]
        Rails.logger.info "Redirect flow data: #{redirect_flow.inspect}"

        # Check if links are available
        if redirect_flow[:links] && redirect_flow[:links].customer && redirect_flow[:links].mandate
          # Update organization billing with GoCardless details
          billing = @current_organization.organization_billing || @current_organization.build_organization_billing
          billing.update!(
            provider: "gocardless",
            gocardless_customer_id: redirect_flow[:links].customer,
            gocardless_mandate_id: redirect_flow[:links].mandate,
            billing_status: "active"
          )
        else
          Rails.logger.warn "GoCardless redirect flow completed but links not available yet"
          # Still update the provider but without customer/mandate IDs
          billing = @current_organization.organization_billing || @current_organization.build_organization_billing
          billing.update!(
            provider: "gocardless",
            billing_status: "pending"
          )
        end

        # Charge onboarding fee
        onboarding_result = OnboardingFeeService.charge_onboarding_fee!(@current_organization)

        if onboarding_result[:success]
          Rails.logger.info "Onboarding fee charged successfully for organization #{@current_organization.id}"
        else
          Rails.logger.error "Failed to charge onboarding fee for organization #{@current_organization.id}: #{onboarding_result[:error]}"
          # Don't fail the GoCardless setup if onboarding fee fails - just log it
        end

        # Clear session
        session.delete(:gocardless_redirect_flow_id)
        session.delete(:gocardless_session_token)

        redirect_to "#{tenant_activation_billing_path}?gocardless=success", notice: "Direct debit authorization completed successfully! ✅"
      else
        # Clear session on failure
        session.delete(:gocardless_redirect_flow_id)
        session.delete(:gocardless_session_token)
        redirect_to tenant_activation_billing_path, alert: "Authorization failed: #{result[:error]}"
      end
    rescue => e
      Rails.logger.error "GoCardless completion error: #{e.message}"
      # Clear session on error
      session.delete(:gocardless_redirect_flow_id)
      session.delete(:gocardless_session_token)
      redirect_to tenant_activation_billing_path, alert: "Failed to complete authorization. Please try again."
    end
  end

  def webhook
    # Verify webhook signature
    payload = request.body.read
    signature = request.headers["Webhook-Signature"]

    gocardless_service = GocardlessService.new
    result = gocardless_service.handle_webhook(payload, signature)

    if result[:success]
      # Process webhook events
      events = result[:events]
      events.each do |event|
        process_webhook_event(event)
      end

      render json: { status: "success" }
    else
      Rails.logger.error "GoCardless webhook error: #{result[:error]}"
      render json: { status: "error", message: result[:error] }, status: :bad_request
    end
  end

  private

  def process_webhook_event(event)
    case event["resource_type"]
    when "mandates"
      process_mandate_event(event)
    when "payments"
      process_payment_event(event)
    when "subscriptions"
      process_subscription_event(event)
    end
  end

  def process_mandate_event(event)
    mandate_id = event["links"]["mandate"]
    action = event["action"]

    case action
    when "submitted", "active"
      # Mandate is ready for payments
      Rails.logger.info "Mandate #{mandate_id} is now #{action}"
    when "cancelled", "failed"
      # Mandate is no longer valid
      Rails.logger.info "Mandate #{mandate_id} is #{action}"
      # You might want to notify the organization or update billing status
    end
  end

  def process_payment_event(event)
    payment_id = event["links"]["payment"]
    action = event["action"]

    case action
    when "confirmed"
      # Payment was successful
      Rails.logger.info "Payment #{payment_id} confirmed"
      # You might want to update billing records or send confirmation emails
    when "failed", "cancelled"
      # Payment failed
      Rails.logger.info "Payment #{payment_id} #{action}"
      # You might want to notify the organization or retry the payment
    end
  end

  def process_subscription_event(event)
    subscription_id = event["links"]["subscription"]
    action = event["action"]

    case action
    when "created", "customer_approval_granted"
      # Subscription is active
      Rails.logger.info "Subscription #{subscription_id} is #{action}"
    when "cancelled", "finished"
      # Subscription ended
      Rails.logger.info "Subscription #{subscription_id} is #{action}"
      # You might want to update billing status or notify the organization
    end
  end
end

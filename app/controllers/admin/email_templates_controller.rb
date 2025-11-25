class Admin::EmailTemplatesController < Admin::BaseController
  before_action :set_email_template_key, only: %i[new create]
  before_action :set_email_template, only: %i[show edit update destroy]

  def index
    set_filter_options

    @email_templates = EmailTemplate.includes(:email_template_key)
    @email_templates = apply_filters(@email_templates)
    @email_templates = @email_templates.order("email_template_keys.name ASC, email_templates.locale ASC")
  end

  def show; end

  def new
    @email_template = @email_template_key.email_templates.build(locale: @email_template_key.default_locale)
  end

  def edit; end

  def create
    @email_template = @email_template_key.email_templates.build(email_template_params)
    @email_template.created_by = current_user
    @email_template.updated_by = current_user

    if @email_template.save
      redirect_to admin_email_template_path(@email_template), notice: "Email template created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @email_template.updated_by = current_user
    if @email_template.update(email_template_params)
      redirect_to admin_email_template_path(@email_template), notice: "Email template updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    key = @email_template.email_template_key
    if @email_template.destroy
      redirect_to admin_email_template_key_path(key), notice: "Email template deleted."
    else
      redirect_to admin_email_template_path(@email_template), alert: "Unable to delete template."
    end
  end

  private

  def set_email_template_key
    @email_template_key = EmailTemplateKey.find(params[:email_template_key_id])
  end

  def set_email_template
    @email_template = EmailTemplate.find(params[:id])
  end

  def email_template_params
    params.require(:email_template).permit(
      :locale,
      :subject,
      :body_html,
      :body_text,
      :active
    )
  end

  def set_filter_options
    @template_keys = EmailTemplateKey.order(:name)
    @search_placeholder = "Subject, key, or name..."
    @status_options = [ [ "Active", "active" ], [ "Inactive", "inactive" ] ]
    @use_status_for_action_type = true
    @custom_selects = [
      {
        param: :email_template_key_id,
        label: "Template Key",
        options: [ [ "All keys", "" ] ] + @template_keys.map { |k| [ k.name, k.id ] }
      }
    ]
    @custom_inputs = [
      {
        param: :locale,
        label: "Locale",
        placeholder: "e.g. en"
      }
    ]
  end

  def apply_filters(scope)
    if params[:email_template_key_id].present?
      scope = scope.where(email_template_key_id: params[:email_template_key_id])
    end

    if params[:search].present?
      pattern = "%#{params[:search]}%"
      scope = scope.joins(:email_template_key).where(
        "email_templates.subject ILIKE :pattern OR email_template_keys.name ILIKE :pattern OR email_template_keys.key ILIKE :pattern",
        pattern: pattern
      )
    end

    case params[:status]
    when "active"
      scope = scope.where(email_templates: { active: true })
    when "inactive"
      scope = scope.where(email_templates: { active: false })
    end

    if params[:locale].present?
      scope = scope.where(locale: params[:locale])
    end

    scope
  end
end

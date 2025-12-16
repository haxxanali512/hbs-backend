class Admin::EmailTemplateKeysController < Admin::BaseController
  before_action :set_email_template_key, only: %i[show edit update destroy]

  def index
    set_filter_options

    @email_template_keys = EmailTemplateKey.all
    @email_template_keys = apply_filters(@email_template_keys)
    @email_template_keys = @email_template_keys.order(:name)
    @pagy, @email_template_keys = pagy(@email_template_keys, items: 20)
  end

  def show
    @email_templates = @email_template_key.email_templates.order(:locale)
  end

  def new
    @email_template_key = EmailTemplateKey.new(default_locale: "en")
  end

  def edit; end

  def create
    @email_template_key = EmailTemplateKey.new(email_template_key_params)

    if @email_template_key.save
      redirect_to admin_email_template_key_path(@email_template_key), notice: "Email template key created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @email_template_key.update(email_template_key_params)
      redirect_to admin_email_template_key_path(@email_template_key), notice: "Email template key updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @email_template_key.destroy
      redirect_to admin_email_template_keys_path, notice: "Email template key deleted."
    else
      redirect_to admin_email_template_key_path(@email_template_key), alert: "Unable to delete this template key."
    end
  end

  private

  def set_email_template_key
    @email_template_key = EmailTemplateKey.find(params[:id])
  end

  def email_template_key_params
    params.require(:email_template_key).permit(
      :key,
      :name,
      :description,
      :default_subject,
      :default_body_html,
      :default_body_text,
      :default_locale,
      :active
    )
  end

  def set_filter_options
    @search_placeholder = "Name or key..."
    @status_options = [ [ "Active", "active" ], [ "Inactive", "inactive" ] ]
    @use_status_for_action_type = true
  end

  def apply_filters(scope)
    if params[:search].present?
      pattern = "%#{params[:search]}%"
      scope = scope.where("name ILIKE ? OR key ILIKE ?", pattern, pattern)
    end

    case params[:status]
    when "active"
      scope = scope.where(active: true)
    when "inactive"
      scope = scope.where(active: false)
    end

    scope
  end
end

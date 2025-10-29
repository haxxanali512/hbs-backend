class Admin::AuditsController < Admin::BaseController
  def index
    @audits = Audited::Audit.includes(:user, :auditable).order(created_at: :desc)

    # Filtering by model type
    if params[:auditable_type].present?
      @audits = @audits.where(auditable_type: params[:auditable_type])
    end

    # Filtering by action
    if params[:action_type].present?
      @audits = @audits.where(action: params[:action_type])
    end

    # Filtering by user
    if params[:user_id].present?
      @audits = @audits.where(user_id: params[:user_id])
    end

    # Filtering by date range
    if params[:date_from].present?
      @audits = @audits.where("created_at >= ?", Date.parse(params[:date_from]).beginning_of_day)
    end

    if params[:date_to].present?
      @audits = @audits.where("created_at <= ?", Date.parse(params[:date_to]).end_of_day)
    end

    # Search functionality
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @audits = @audits.joins(:auditable).where(
        "audited_audits.comment ILIKE ? OR audited_audits.remote_address ILIKE ?",
        search_term, search_term
      )
    end

    # Pagination
    @pagy, @audits = pagy(@audits, items: 20)

    # For shared filters partial
    @search_placeholder = "Comment, IP address..."
    @status_options = Audited::Audit.reorder(nil).distinct.pluck(:action).compact.sort
    @user_options = User.where(id: Audited::Audit.reorder(nil).distinct.pluck(:user_id).compact).order(:email)
    @extra_select = Audited::Audit.reorder(nil).distinct.pluck(:auditable_type).compact.sort
    @show_date_range = true
  end

  def show
    @audit = Audited::Audit.find(params[:id])
    @auditable = @audit.auditable
    @user = @audit.user
  end

  def model_audits
    @auditable_type = params[:auditable_type]
    @auditable_id = params[:auditable_id]

    @auditable = @auditable_type.constantize.find(@auditable_id) if @auditable_type.present? && @auditable_id.present?

    @audits = Audited::Audit.where(auditable_type: @auditable_type, auditable_id: @auditable_id)
                           .preload(:user)
                           .order(created_at: :desc)

    # Filtering by action
    if params[:action_type].present?
      @audits = @audits.where(action: params[:action_type])
    end

    # Filtering by user
    if params[:user_id].present?
      @audits = @audits.where(user_id: params[:user_id])
    end

    # Filtering by date range
    if params[:date_from].present?
      @audits = @audits.where("created_at >= ?", Date.parse(params[:date_from]).beginning_of_day)
    end

    if params[:date_to].present?
      @audits = @audits.where("created_at <= ?", Date.parse(params[:date_to]).end_of_day)
    end

    # Pagination
    @pagy, @audits = pagy(@audits, items: 20)

    # For shared filters partial
    @search_placeholder = "Comment, IP address..."
    @status_options = @audits.reorder(nil).distinct.pluck(:action).compact.sort
    @user_options = User.where(id: @audits.reorder(nil).distinct.pluck(:user_id).compact).order(:email)
    @auditable_type = params[:auditable_type]
    @auditable_id = params[:auditable_id]
    @show_date_range = true
  end

  private

  def audit_params
    params.permit(:auditable_type, :action_type, :user_id, :date_from, :date_to, :search)
  end
end

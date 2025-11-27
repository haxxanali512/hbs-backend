class Admin::PayersController < Admin::BaseController
  include Admin::Concerns::EzclaimIntegration

  # Alias the concern method before we override it
  alias_method :fetch_from_ezclaim_concern, :fetch_from_ezclaim

  before_action :set_payer, only: [ :show, :edit, :update, :destroy ]

  def index
    @payers = Payer.order(:name)

    # Search filter
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @payers = @payers.where("name ILIKE ? OR hbs_payer_key ILIKE ?", search_term, search_term)
    end

    # Status filter
    if params[:status].present?
      @payers = @payers.where(status: params[:status])
    end

    # Payer type filter
    if params[:payer_type].present?
      @payers = @payers.where(payer_type: params[:payer_type])
    end

    @pagy, @payers = pagy(@payers, items: 20)
  end

  def show; end

  def new
    @payer = Payer.new(status: :draft)
  end

  def create
    @payer = Payer.new(payer_params)
    if @payer.save
      redirect_to admin_payer_path(@payer), notice: "Payer created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @payer.update(payer_params)
      redirect_to admin_payer_path(@payer), notice: "Payer updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    redirect_to admin_payers_path, alert: "Payers cannot be hard deleted. Retire instead."
  end

  def fetch_from_ezclaim
    fetch_from_ezclaim_concern(resource_type: :payers, service_method: :get_payers)
  end

  def save_from_ezclaim
    perform_ezclaim_save(
      model_class: Payer,
      data_key: :payers,
      mapping_proc: ->(payer_data) {
        {
          find_by: {
            hbs_payer_key: payer_data["payer_id"] || payer_data["id"]
          },
          attributes: {
            name: payer_data["name"] || payer_data["payer_name"] || "Unknown Payer",
            payer_type: map_ezclaim_payer_type(payer_data["payer_type"] || payer_data["type"]),
            status: :draft,
            national_payer_id: payer_data["national_payer_id"] || payer_data["payer_id"] || payer_data["id"],
            hbs_payer_key: payer_data["payer_id"] || payer_data["id"] || payer_data["hbs_payer_key"]
          }
        }
      }
    )
  end

  private

  def set_payer
    @payer = Payer.find(params[:id])
  end

  def payer_params
    params.require(:payer).permit(
      :name, :payer_type, :id_namespace, :national_payer_id, :contact_url, :support_phone,
      :notes_internal, :status, :hbs_payer_key, :search_tokens, state_scope: []
    )
  end

  def map_ezclaim_payer_type(ezclaim_type)
    return :other if ezclaim_type.blank?

    type_str = ezclaim_type.to_s.downcase
    case type_str
    when /medicare/
      :medicare
    when /medicaid/
      :medicaid
    when /workers.*comp|wcomp/
      :workers_comp
    when /auto/
      :auto
    when /commercial|commercial/
      :commercial
    else
      :other
    end
  end
end

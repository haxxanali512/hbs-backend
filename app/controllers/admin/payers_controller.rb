class Admin::PayersController < Admin::BaseController
  before_action :set_payer, only: [ :show, :edit, :update, :destroy ]

  def index
    @payers = Payer.order(:name)
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
end

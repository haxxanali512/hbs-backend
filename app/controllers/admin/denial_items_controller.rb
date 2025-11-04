class Admin::DenialItemsController < Admin::BaseController
  before_action :set_claim
  before_action :set_denial
  before_action :set_item, only: [ :update ]

  def create
    item = @denial.denial_items.new(item_params)
    if item.save
      redirect_to admin_claim_denial_path(@claim, @denial), notice: "Denial item added."
    else
      redirect_to admin_claim_denial_path(@claim, @denial), alert: item.errors.full_messages.join(", ")
    end
  end

  def update
    if @item.update(item_params)
      redirect_to admin_claim_denial_path(@claim, @denial), notice: "Denial item updated."
    else
      redirect_to admin_claim_denial_path(@claim, @denial), alert: @item.errors.full_messages.join(", ")
    end
  end

  private

  def set_claim
    @claim = Claim.find(params[:claim_id])
  end

  def set_denial
    @denial = @claim.denials.find(params[:denial_id])
  end

  def set_item
    @item = @denial.denial_items.find(params[:id])
  end

  def item_params
    params.require(:denial_item).permit(:claim_line_id, :amount_denied, carc_codes: [], rarc_codes: [])
  end
end

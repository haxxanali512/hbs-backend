class InsurancePlan < ApplicationRecord
  audited

  # =========================
  # Associations
  # =========================
  belongs_to :payer
  has_many :org_accepted_plans, dependent: :restrict_with_error
  has_many :patient_insurance_coverages, dependent: :restrict_with_error
  # has_many :eligibility_checks, dependent: :nullify
  has_many :claim_submissions, dependent: :nullify

  # =========================
  # Enums
  # =========================
  enum :plan_type, {
    ppo: 0,
    hmo: 1,
    epo: 2,
    pos: 3,
    medicare_advantage: 4,
    medicaid_managed: 5,
    medicaid_ffs: 6,
    workers_comp: 7,
    auto: 8,
    other: 9
  }

  enum :status, {
    draft: 0,
    active: 1,
    retired: 2
  }

  US_STATE_CODES = %w[AL AK AZ AR CA CO CT DE FL GA HI ID IL IN IA KS KY LA ME MD MA MI MN MS MO MT NE NV NH NJ NM NY NC ND OH OK OR PA RI SC SD TN TX UT VT VA WA WV WI WY DC].freeze

  MAX_NAME_LENGTH = 200
  MAX_PLAN_CODE_LENGTH = 100

  # =========================
  # Validations
  # =========================
  validates :payer_id, :name, :plan_type, :plan_code, presence: true
  validates :name, length: { in: 1..MAX_NAME_LENGTH }
  validates :plan_code, length: { in: 1..MAX_PLAN_CODE_LENGTH }
  validates :plan_code, uniqueness: { scope: :payer_id, message: "PLAN_CODE_DUPLICATE" }
  validates :plan_type, inclusion: { in: plan_types.keys, message: "PLAN_TYPE_INVALID" }
  validates :contact_url, format: { with: URI::DEFAULT_PARSER.make_regexp, allow_blank: true }
  validate :state_scope_subset_of_payer_scope
  validate :state_scope_codes_valid
  validate :plan_type_immutability, on: :update
  validate :retire_blocked_check, on: :update

  # =========================
  # Scopes
  # =========================
  scope :active_only, -> { where(status: :active) }
  scope :for_payer, ->(payer_id) { where(payer_id: payer_id) }
  scope :by_plan_type, ->(type) { where(plan_type: type) }
  scope :in_state, ->(state_code) { where("? = ANY(state_scope)", state_code) }

  # =========================
  # Callbacks
  # =========================
  before_validation :normalize_name
  before_validation :normalize_plan_code

  # =========================
  # Business Logic
  # =========================
  def retire!(reason: nil, actor: nil)
    # Check if retirement is blocked
    unless can_retire?
      errors.add(:base, "PLAN_RETIRE_BLOCKED")
      return false
    end

    update(status: :retired)
  end

  def restore!
    update(status: :active)
  end

  def can_retire?
    # Check for active org acceptances and patient coverages
    # TODO: Implement when org_accepted_plans and patient_insurance_coverages are created
    # return false if org_accepted_plans.active.exists?
    # return false if patient_insurance_coverages.active.exists?
    true
  end

  def validate_member_id(member_id)
    return true if member_id_format.blank?
    return false if member_id.blank?

    regex = Regexp.new(member_id_format)
    regex.match?(member_id)
  end

  def validate_group_number(group_number)
    return true if group_number_format.blank?
    return false if group_number.blank?

    regex = Regexp.new(group_number_format)
    regex.match?(group_number)
  end

  def status_badge_class
    case status.to_s
    when "draft"
      "bg-gray-100 text-gray-800"
    when "active"
      "bg-green-100 text-green-800"
    when "retired"
      "bg-red-100 text-red-800"
    else
      "bg-gray-100 text-gray-800"
    end
  end

  # =========================
  # Private Methods
  # =========================
  private

  def normalize_name
    return unless name.present?

    self.name = name.strip.gsub(/\s+/, " ")
  end

  def normalize_plan_code
    return unless plan_code.present?

    self.plan_code = plan_code.strip.upcase
  end

  def state_scope_subset_of_payer_scope
    return unless payer && state_scope.present? && payer.state_scope.present?

    invalid_states = state_scope - payer.state_scope
    if invalid_states.any?
      errors.add(:state_scope, "PLAN_SCOPE_NOT_SUBSET")
    end
  end

  def state_scope_codes_valid
    return if state_scope.blank?

    invalid = state_scope.reject { |c| US_STATE_CODES.include?(c) }
    errors.add(:state_scope, "Invalid state codes: #{invalid.join(', ')}") if invalid.any?
  end

  def plan_type_immutability
    return unless will_save_change_to_plan_type?
    return if draft? # Can change type in draft

    # Type change requires step-up MFA (enforced at controller level)
    unless _skip_type_change_validation
      errors.add(:plan_type, "PLAN_TYPE_CHANGE_STEPUP_REQUIRED")
    end
  end

  def retire_blocked_check
    return unless will_save_change_to_status? && retired?

    unless can_retire? || _skip_retire_validation
      errors.add(:status, "PLAN_RETIRE_BLOCKED")
    end
  end

  # Allow controller to bypass validations with step-up MFA
  attr_accessor :_skip_type_change_validation
  attr_accessor :_skip_retire_validation
end

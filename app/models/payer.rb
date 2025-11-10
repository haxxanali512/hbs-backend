class Payer < ApplicationRecord
  audited

  has_many :claim_gen_payer_routes, dependent: :destroy
  has_many :claim_submissions, dependent: :nullify
  has_many :claims, dependent: :nullify
  has_many :payments, dependent: :nullify
  has_many :payer_enrollments, dependent: :restrict_with_error
  has_many :insurance_plans, dependent: :restrict_with_error

  enum :payer_type, {
    commercial: 0,
    medicare: 1,
    medicaid: 2,
    workers_comp: 3,
    auto: 4,
    other: 5
  }

  enum :id_namespace, {
    changehealthcare: 0,
    availity: 1,
    other_network: 2
  }, prefix: true

  enum :status, { draft: 0, active: 1, retired: 2 }

  US_STATE_CODES = %w[AL AK AZ AR CA CO CT DE FL GA HI ID IL IN IA KS KY LA ME MD MA MI MN MS MO MT NE NV NH NJ NM NY NC ND OH OK OR PA RI SC SD TN TX UT VT VA WA WV WI WY DC].freeze

  validates :name, presence: true, length: { in: 1..200 }
  validates :payer_type, presence: { message: "PAYER_TYPE_INVALID" }
  validates :hbs_payer_key, presence: { message: "PAYER_ROUTING_KEY_REQUIRED" }, if: :activating?
  validates :national_payer_id, uniqueness: { scope: :id_namespace, message: "PAYER_NAMESPACE_ID_CONFLICT", allow_nil: true, allow_blank: true }
  validate  :name_uniqueness_among_active
  validate  :state_scope_codes_valid
  validate  :payer_type_change_requires_step_up, on: :update
  validates :contact_url, format: { with: URI::DEFAULT_PARSER.make_regexp, allow_blank: true }
  validates :support_phone, format: { with: /\A\+?[1-9]\d{1,14}\z/, allow_blank: true }

  before_validation :normalize_name_and_tokens

  scope :active_only, -> { where(status: :active) }

  def activating?
    status.to_s == "active"
  end

  def name_uniqueness_among_active
    return if name.blank?
    normalized = normalize_for_compare(name)
    clash = Payer.where(status: :active).where.not(id: id).find { |p| normalize_for_compare(p.name) == normalized }
    errors.add(:name, "PAYER_NAME_DUPLICATE") if clash
  end

  def state_scope_codes_valid
    return if state_scope.blank?
    invalid = state_scope.reject { |c| US_STATE_CODES.include?(c) }
    errors.add(:state_scope, "PAYER_STATE_SCOPE_INVALID") if invalid.any?
  end

  def payer_type_change_requires_step_up
    return unless will_save_change_to_payer_type?
    errors.add(:payer_type, "PAYER_TYPE_CHANGE_STEPUP_REQUIRED")
  end

  def normalize_name_and_tokens
    self.name = name.to_s.squish if name.present?
    self.search_tokens = [ name, hbs_payer_key, national_payer_id ].compact.join(" ") if respond_to?(:search_tokens)
  end

  def normalize_for_compare(val)
    val.to_s.downcase.gsub(/\s+/, " ").strip
  end
end

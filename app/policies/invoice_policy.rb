class InvoicePolicy < ApplicationPolicy
  def index?
    admin? || member_of_organization?
  end

  def show?
    admin? || member_of_organization?
  end

  def new?
    admin?
  end

  def create?
    admin?
  end

  def edit?
    admin? && record.draft?
  end

  def update?
    admin? && record.draft?
  end

  def issue?
    admin? && record.draft?
  end

  def void?
    admin? && (record.issued? || record.partially_paid?)
  end

  def apply_payment?
    admin?
  end

  def pay?
    member_of_organization? && (record.issued? || record.partially_paid?)
  end

  private

  def member_of_organization?
    user.present? && user.member_of?(record.organization)
  end

  class Scope < Scope
    def resolve
      if user&.admin?
        scope.all
      elsif user.present?
        scope.where(organization: user.organizations)
      else
        scope.none
      end
    end
  end
end

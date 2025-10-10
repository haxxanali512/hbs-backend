class TenantContext
  def self.current_organization
    Thread.current[:current_organization]
  end

  def self.current_organization=(org)
    Thread.current[:current_organization] = org
  end

  def self.current_organization_from_session(session)
    return nil unless session[:current_organization_id]
    Organization.find_by(id: session[:current_organization_id])
  end

  def self.with_organization(org, &block)
    previous = current_organization
    self.current_organization = org
    yield
  ensure
    self.current_organization = previous
  end

  def self.current_user
    Thread.current[:current_user]
  end

  def self.current_user=(user)
    Thread.current[:current_user] = user
  end

  def self.current_membership
    Thread.current[:current_membership]
  end

  def self.current_membership=(membership)
    Thread.current[:current_membership] = membership
  end

  def self.with_context(user:, organization:, membership: nil, &block)
    previous_user = current_user
    previous_org = current_organization
    previous_membership = current_membership

    self.current_user = user
    self.current_organization = organization
    self.current_membership = membership

    yield
  ensure
    self.current_user = previous_user
    self.current_organization = previous_org
    self.current_membership = previous_membership
  end

  def self.clear!
    Thread.current[:current_organization] = nil
    Thread.current[:current_user] = nil
    Thread.current[:current_membership] = nil
  end
end

# Seed: Multi-tenant medical billing system setup

require_relative "../lib/hbs_customs/module_permission"

super_admin_email = "admin@holisticbusinesssolution.com"
super_admin_password = "Password!123"

puts "Seeding Multi-tenant Medical Billing System..."

# Create Super Admin Role (Global)
super_admin_role = Role.find_or_initialize_by(role_name: "Super Admin")
super_admin_role.scope = :global
super_admin_role.organization_id = nil
super_admin_role.access = HbsCustoms::ModulePermission.full_access
super_admin_role.save!

# Create Global User Manager Role
global_user_manager_role = Role.find_or_initialize_by(role_name: "Global User Manager")
global_user_manager_role.scope = :global
global_user_manager_role.organization_id = nil
global_user_manager_role.access = HbsCustoms::ModulePermission.global_admin_access
global_user_manager_role.save!

# Create Super Admin User
super_admin_user = User.find_or_initialize_by(email: super_admin_email)
super_admin_user.username ||= "superadmin"
super_admin_user.first_name ||= "Super"
super_admin_user.last_name ||= "Admin"
super_admin_user.password = super_admin_password if super_admin_user.encrypted_password.blank?
super_admin_user.password_confirmation = super_admin_password if super_admin_user.encrypted_password.blank?
super_admin_user.role = super_admin_role
super_admin_user.save!

# Create Test Organization
test_org = Organization.find_or_initialize_by(subdomain: "test-org")
test_org.name ||= "Test Medical Practice"
test_org.owner = super_admin_user
test_org.tier ||= "premium"
test_org.activation_status ||= :activated
test_org.save!

# Create Tenant Roles for Test Organization
tenant_admin_role = Role.find_or_initialize_by(role_name: "Organization Admin", organization: test_org)
tenant_admin_role.scope = :tenant
tenant_admin_role.organization = test_org
tenant_admin_role.access = HbsCustoms::ModulePermission.tenant_admin_access
tenant_admin_role.save!

billing_manager_role = Role.find_or_initialize_by(role_name: "Billing Manager", organization: test_org)
billing_manager_role.scope = :tenant
billing_manager_role.organization = test_org
billing_manager_role.access = HbsCustoms::ModulePermission.billing_manager_access
billing_manager_role.save!

clinical_staff_role = Role.find_or_initialize_by(role_name: "Clinical Staff", organization: test_org)
clinical_staff_role.scope = :tenant
clinical_staff_role.organization = test_org
clinical_staff_role.access = HbsCustoms::ModulePermission.clinical_staff_access
clinical_staff_role.save!

# Create Organization Memberships
# Super admin as organization admin
super_admin_membership = OrganizationMembership.find_or_initialize_by(user: super_admin_user, organization: test_org)
super_admin_membership.organization_role = tenant_admin_role
super_admin_membership.active = true
super_admin_membership.save!

# Create additional test users for the organization
test_users = [
  {
    email: "billing@test-org.com",
    username: "billing_manager",
    first_name: "Billing",
    last_name: "Manager",
    role: billing_manager_role
  },
  {
    email: "clinical@test-org.com",
    username: "clinical_staff",
    first_name: "Clinical",
    last_name: "Staff",
    role: clinical_staff_role
  }
]

test_users.each do |user_data|
  user = User.find_or_initialize_by(email: user_data[:email])
  user.username ||= user_data[:username]
  user.first_name ||= user_data[:first_name]
  user.last_name ||= user_data[:last_name]
  user.password = "Password!123" if user.encrypted_password.blank?
  user.password_confirmation = "Password!123" if user.encrypted_password.blank?
  user.save!

  # Create membership
  membership = OrganizationMembership.find_or_initialize_by(user: user, organization: test_org)
  membership.organization_role = user_data[:role]
  membership.active = true
  membership.save!
end

# Create another organization for testing multi-tenancy
demo_org = Organization.find_or_initialize_by(subdomain: "demo-clinic")
demo_org.name ||= "Demo Medical Clinic"
demo_org.owner = super_admin_user
demo_org.tier ||= "standard"
demo_org.activation_status ||= :billing_setup
demo_org.save!

# Create tenant roles for demo organization
demo_admin_role = Role.find_or_initialize_by(role_name: "Organization Admin", organization: demo_org)
demo_admin_role.scope = :tenant
demo_admin_role.organization = demo_org
demo_admin_role.access = HbsCustoms::ModulePermission.tenant_admin_access
demo_admin_role.save!

# Create membership for demo org
demo_membership = OrganizationMembership.find_or_initialize_by(user: super_admin_user, organization: demo_org)
demo_membership.organization_role = demo_admin_role
demo_membership.active = true
demo_membership.save!

puts "\n=== Seeding Complete ==="
puts "Super Admin: #{super_admin_user.email} (password: #{super_admin_password})"
puts "Test Organization: #{test_org.name} (subdomain: #{test_org.subdomain})"
puts "Demo Organization: #{demo_org.name} (subdomain: #{demo_org.subdomain})"
puts "\nTest Users:"
puts "- billing@test-org.com (password: Password!123)"
puts "- clinical@test-org.com (password: Password!123)"
puts "\nAccess URLs:"
puts "- Global Admin: http://admin.localhost:3000"
puts "- Test Org: http://test-org.localhost:3000"
puts "- Demo Org: http://demo-clinic.localhost:3000"

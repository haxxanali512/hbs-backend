# Seed: Super Admin user with full-access role

require_relative "../lib/hbs_customs/module_permission"

super_admin_email = "admin@holisticbusinesssolution.com"
super_admin_password = "Password!123"

puts "Seeding Super Admin user and role..."

user = User.find_or_initialize_by(email: super_admin_email)
user.username ||= "superadmin"
user.first_name ||= "Super"
user.last_name ||= "Admin"
user.password = super_admin_password if user.encrypted_password.blank?
user.password_confirmation = super_admin_password if user.encrypted_password.blank?
user.save!

# Create or update a full access role and attach to the user (has_one)
full_access_permissions = ModulePermission.full_access

role = user.role || Role.find_or_initialize_by(role_name: "Super Admin")
role.user = user
role.access = full_access_permissions
role.save!

puts "Super Admin: #{user.email} (password: #{super_admin_password})"
puts "Role '#{role.role_name}' assigned with full access."

# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

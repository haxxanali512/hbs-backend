module Admin
  module Concerns
    module OrganizationConcern
      extend ActiveSupport::Concern

      included do
        before_action :load_users, only: [ :new, :create, :edit, :update ]
      end

      private

      # Load all users for member selection
      def load_users
        @users = User.all.order(:first_name, :last_name)
      end

      # Build associated records if they don't exist
      def build_organization_associations
        return unless @organization
        @organization.build_organization_setting unless @organization.organization_setting
        @organization.build_organization_contact unless @organization.organization_contact
        @organization.build_organization_identifier unless @organization.organization_identifier
      end

      # Build the base query for organizations index
      def build_organizations_index_query
        Organization.kept.includes(:owner).order(created_at: :desc)
      end

      # Apply search filter to organizations
      def apply_organizations_search(organizations)
        return organizations unless params[:search].present?
        organizations.where("name ILIKE ?", "%#{params[:search]}%")
      end

      # Apply status filter to organizations
      def apply_organizations_status_filter(organizations)
        return organizations unless params[:status].present?
        organizations.where(activation_status: params[:status])
      end

      # Handle member assignments for organization
      def assign_organization_members(organization, member_ids_param)
        return unless member_ids_param.present?

        member_ids = member_ids_param.reject(&:blank?)
        return if member_ids.empty?

        member_ids.each do |user_id|
          user = User.find_by(id: user_id)
          organization.add_member(user, nil) if user
        end
      end

      # Update organization members (add new, remove deselected)
      def update_organization_members(organization, member_ids_param)
        return unless member_ids_param.present?

        member_ids = member_ids_param.reject(&:blank?)
        current_member_ids = organization.members.pluck(:id).map(&:to_s)

        # Add new members
        new_member_ids = member_ids - current_member_ids
        new_member_ids.each do |user_id|
          user = User.find_by(id: user_id)
          organization.add_member(user, nil) if user
        end

        # Deactivate members that are no longer selected
        removed_member_ids = current_member_ids - member_ids
        removed_member_ids.each do |user_id|
          membership = organization.organization_memberships.find_by(user_id: user_id)
          membership&.update(active: false)
        end
      end

      # Prepare organization for form rendering (used in error cases)
      def prepare_organization_for_form
        load_users
        build_organization_associations
      end

      # Create organization with all associations and members
      def create_organization_with_associations
        @organization = Organization.new(organization_params)

        if @organization.save
          # Add owner as member
          @organization.add_member(@organization.owner, nil)

          # Add additional members if provided
          assign_organization_members(@organization, params[:member_ids])

          # Send notification
          NotificationService.notify_organization_created(@organization)

          true
        else
          prepare_organization_for_form
          false
        end
      end

      # Update organization with all associations and members
      def update_organization_with_associations
        changes = @organization.changes

        # Update members first
        update_organization_members(@organization, params[:member_ids])

        # Update organization attributes
        if @organization.update(organization_params)
          NotificationService.notify_organization_updated(@organization, changes)
          true
        else
          prepare_organization_for_form
          false
        end
      end

      # Get success message for organization creation
      def organization_created_message
        subdomain_url = if Rails.env.development?
          "#{@organization.subdomain}.localhost:3000"
        else
          host = ENV.fetch("HOST", request.host_with_port)
          "#{@organization.subdomain}.#{host}"
        end
        "Organization created successfully. The owner (#{@organization.owner.email}) must complete activation at #{subdomain_url}"
      end

      # Get error message for organization creation
      def organization_creation_error_message
        "Failed to create organization: #{@organization.errors.full_messages.join(', ')}"
      end
    end
  end
end

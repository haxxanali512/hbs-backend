module Admin
  module Concerns
    module EzclaimIntegration
      extend ActiveSupport::Concern

      # Generic method to fetch data from EZclaim API
      # Usage: fetch_from_ezclaim(resource_type: :payers, service_method: :get_payers)
      def fetch_from_ezclaim(resource_type:, service_method:)
        organization = find_ezclaim_organization

        unless organization
          render json: {
            success: false,
            error: "No organization with EZclaim enabled found. Please configure EZclaim in organization settings."
          }, status: :unprocessable_entity
          return
        end

        unless organization.organization_setting&.ezclaim_enabled?
          render json: {
            success: false,
            error: "EZclaim is not enabled for this organization."
          }, status: :unprocessable_entity
          return
        end

        begin
          service = EzclaimService.new(organization: organization)
          result = service.public_send(service_method)

          if result[:success] && result[:data]
            # Handle both array and object responses
            items = result[:data].is_a?(Array) ? result[:data] : (result[:data][resource_type.to_s.pluralize] || result[:data]["data"] || [])

            render json: {
              success: true,
              data: items,
              count: items.length,
              resource_type: resource_type.to_s
            }
          else
            render json: {
              success: false,
              error: result[:error] || "Failed to fetch #{resource_type} from EZclaim"
            }, status: :unprocessable_entity
          end
        rescue EzclaimService::AuthenticationError => e
          render json: {
            success: false,
            error: "Authentication failed: #{e.message}"
          }, status: :unauthorized
        rescue EzclaimService::IntegrationError => e
          render json: {
            success: false,
            error: "Integration error: #{e.message}"
          }, status: :unprocessable_entity
        rescue => e
          Rails.logger.error("EZclaim fetch #{resource_type} error: #{e.message}")
          render json: {
            success: false,
            error: "Unexpected error: #{e.message}"
          }, status: :internal_server_error
        end
      end

      # Generic method to save data from EZclaim to database
      # Usage: save_from_ezclaim(model_class: Payer, data_key: :payers, mapping_proc: ->(item) { ... })
      # Or use resource-specific helpers like: save_patients_from_ezclaim
      def save_from_ezclaim(model_class:, data_key:, mapping_proc:)
        items_data = params[data_key] || []

        if items_data.empty?
          render json: {
            success: false,
            error: "No #{data_key} selected"
          }, status: :unprocessable_entity
          return
        end

        saved_count = 0
        skipped_count = 0
        errors = []

        items_data.each do |item_data|
          begin
            mapped_attributes = mapping_proc.call(item_data)

            # Skip if mapping_proc returns skip flag
            if mapped_attributes[:skip]
              skipped_count += 1
              errors << "#{item_data['name'] || item_data['first_name'] || 'Item'}: #{mapped_attributes[:skip_reason] || 'Skipped'}"
              next
            end

            item = model_class.find_or_initialize_by(mapped_attributes[:find_by] || {})

            # Update attributes
            item.assign_attributes(mapped_attributes[:attributes] || {})

            if item.save
              saved_count += 1
            else
              errors << "Failed to save #{item.name || item.full_name || item_data['name'] || 'item'}: #{item.errors.full_messages.join(', ')}"
            end
          rescue => e
            errors << "Error processing item: #{e.message}"
          end
        end

        if saved_count > 0
          message = "Successfully saved #{saved_count} #{data_key.to_s.singularize}(s)"
          message += ". Skipped #{skipped_count} item(s)." if skipped_count > 0

          render json: {
            success: true,
            saved_count: saved_count,
            skipped_count: skipped_count,
            errors: errors,
            message: message
          }
        else
          render json: {
            success: false,
            error: "Failed to save #{data_key}. #{errors.join('; ')}"
          }, status: :unprocessable_entity
        end
      end

      # Patient-specific save method with built-in mapping
      def save_patients_from_ezclaim
        organization_id = get_organization_id_for_save

        unless organization_id
          render json: {
            success: false,
            error: "No organization available. Please select an organization."
          }, status: :unprocessable_entity
          return
        end

        save_from_ezclaim(
          model_class: Patient,
          data_key: :patients,
          mapping_proc: build_patient_mapping_proc(organization_id)
        )
      end

      # Encounter-specific save method with built-in mapping
      def save_encounters_from_ezclaim
        organization_id = get_organization_id_for_save

        unless organization_id
          render json: {
            success: false,
            error: "No organization available. Please select an organization."
          }, status: :unprocessable_entity
          return
        end

        save_from_ezclaim(
          model_class: Encounter,
          data_key: :encounters,
          mapping_proc: build_encounter_mapping_proc(organization_id)
        )
      end

      private

      def find_ezclaim_organization
        organization_id = params[:organization_id]

        if organization_id.present?
          Organization.find_by(id: organization_id)
        else
          # Get the first organization with EZclaim enabled
          Organization.joins(:organization_setting)
                      .where(organization_settings: { ezclaim_enabled: true })
                      .first
        end
      end

      def get_organization_id_for_save
        organization_id = params[:organization_id]
        return organization_id if organization_id.present?

        organization = find_ezclaim_organization
        organization&.id
      end

      def build_patient_mapping_proc(organization_id)
        ->(patient_data) {
          # Validate organization
          unless organization_id
            return skip_item("No organization available. Please select an organization.")
          end

          # Parse date of birth
          dob = parse_date_from_ezclaim(patient_data["dob"])

          # Extract identifiers
          mrn = extract_patient_identifier(patient_data, "mrn")
          external_id = extract_patient_identifier(patient_data, "external_id")

          # Build find_by hash
          find_by_hash = build_patient_find_by_hash(
            mrn: mrn,
            external_id: external_id,
            patient_data: patient_data,
            organization_id: organization_id,
            dob: dob
          )

          # Validate address (required by Patient model)
          address_validation = validate_patient_address(patient_data)
          return skip_item(address_validation[:reason]) unless address_validation[:valid]

          # Build attributes
          {
            find_by: find_by_hash,
            attributes: build_patient_attributes(
              patient_data: patient_data,
              organization_id: organization_id,
              dob: dob,
              mrn: mrn,
              external_id: external_id,
              address: address_validation[:address]
            )
          }
        }
      end

      def parse_date_from_ezclaim(date_string)
        return nil if date_string.blank?

        begin
          Date.parse(date_string)
        rescue
          # Try other date formats
          begin
            Date.strptime(date_string, "%m/%d/%Y")
          rescue
            nil
          end
        end
      end

      def extract_patient_identifier(patient_data, type)
        case type
        when "mrn"
          patient_data["mrn"] || patient_data["patient_id"] || patient_data["id"]
        when "external_id"
          patient_data["external_id"] || patient_data["patient_id"] || patient_data["id"]
        else
          nil
        end
      end

      def build_patient_find_by_hash(mrn:, external_id:, patient_data:, organization_id:, dob:)
        if mrn.present?
          { mrn: mrn, organization_id: organization_id }
        elsif external_id.present?
          { external_id: external_id, organization_id: organization_id }
        else
          # Fallback to name and DOB if available
          hash = {
            first_name: patient_data["first_name"] || patient_data["firstname"] || "",
            last_name: patient_data["last_name"] || patient_data["lastname"] || "",
            organization_id: organization_id
          }
          hash[:dob] = dob if dob.present?
          hash
        end
      end

      def validate_patient_address(patient_data)
        address_line_1 = patient_data["address_line_1"] || patient_data["address"] || patient_data["street"] || ""
        address_line_2 = patient_data["address_line_2"] || patient_data["address2"] || ""

        if address_line_1.blank? && address_line_2.blank?
          { valid: false, reason: "Address is required. Please add address information." }
        else
          {
            valid: true,
            address: {
              address_line_1: address_line_1,
              address_line_2: address_line_2
            }
          }
        end
      end

      def build_patient_attributes(patient_data:, organization_id:, dob:, mrn:, external_id:, address:)
        {
          organization_id: organization_id,
          first_name: patient_data["first_name"] || patient_data["firstname"] || "Unknown",
          last_name: patient_data["last_name"] || patient_data["lastname"] || "Patient",
          dob: dob,
          sex_at_birth: patient_data["sex_at_birth"] || patient_data["gender"] || patient_data["sex"] || nil,
          address_line_1: address[:address_line_1],
          address_line_2: address[:address_line_2],
          city: patient_data["city"] || nil,
          state: patient_data["state"] || nil,
          postal: patient_data["postal"] || patient_data["zip"] || patient_data["zip_code"] || nil,
          country: patient_data["country"] || "US",
          phone_number: patient_data["phone_number"] || patient_data["phone"] || nil,
          email: patient_data["email"] || nil,
          mrn: mrn,
          external_id: external_id,
          status: :active
        }
      end

      def build_encounter_mapping_proc(organization_id)
        ->(encounter_data) {
          # Validate organization
          unless organization_id
            return skip_item("No organization available. Please select an organization.")
          end

          # Parse date of service
          date_of_service = parse_date_from_ezclaim(encounter_data["date_of_service"] || encounter_data["dos"])

          unless date_of_service
            return skip_item("Date of service is required.")
          end

          # Find patient by MRN, external_id, or patient_id
          patient = find_patient_for_encounter(encounter_data, organization_id)
          unless patient
            return skip_item("Patient not found. Please import the patient first.")
          end

          # Find provider by NPI or name
          provider = find_provider_for_encounter(encounter_data, organization_id)
          unless provider
            return skip_item("Provider not found. Please import the provider first.")
          end

          # Find specialty by name or code
          specialty = find_specialty_for_encounter(encounter_data)
          unless specialty
            return skip_item("Specialty not found. Please create the specialty first.")
          end

          # Determine billing channel
          billing_channel = determine_billing_channel(encounter_data)

          # Build find_by hash - use date_of_service, patient_id, provider_id as unique identifier
          find_by_hash = {
            organization_id: organization_id,
            patient_id: patient.id,
            provider_id: provider.id,
            date_of_service: date_of_service
          }

          # Build attributes
          {
            find_by: find_by_hash,
            attributes: build_encounter_attributes(
              encounter_data: encounter_data,
              organization_id: organization_id,
              patient_id: patient.id,
              provider_id: provider.id,
              specialty_id: specialty.id,
              date_of_service: date_of_service,
              billing_channel: billing_channel
            )
          }
        }
      end

      def find_patient_for_encounter(encounter_data, organization_id)
        # Try MRN first
        mrn = encounter_data["patient_mrn"] || encounter_data["mrn"]
        if mrn.present?
          patient = Patient.find_by(mrn: mrn, organization_id: organization_id)
          return patient if patient
        end

        # Try external_id
        external_id = encounter_data["patient_external_id"] || encounter_data["external_id"] || encounter_data["patient_id"]
        if external_id.present?
          patient = Patient.find_by(external_id: external_id, organization_id: organization_id)
          return patient if patient
        end

        # Try patient_id from EZclaim
        patient_id = encounter_data["patient_id"]
        if patient_id.present?
          # Check if it's our internal ID or EZclaim's ID
          patient = Patient.find_by(id: patient_id, organization_id: organization_id)
          return patient if patient
        end

        nil
      end

      def find_provider_for_encounter(encounter_data, organization_id)
        # Try NPI first
        npi = encounter_data["provider_npi"] || encounter_data["npi"]
        if npi.present?
          provider = Provider.find_by(npi: npi)
          # Check if provider is assigned to organization
          if provider && provider.organizations.include?(Organization.find(organization_id))
            return provider
          end
        end

        # Try provider_id from EZclaim
        provider_id = encounter_data["provider_id"]
        if provider_id.present?
          provider = Provider.find_by(id: provider_id)
          if provider && provider.organizations.include?(Organization.find(organization_id))
            return provider
          end
        end

        # Try by name (less reliable)
        first_name = encounter_data["provider_first_name"] || encounter_data["provider_firstname"]
        last_name = encounter_data["provider_last_name"] || encounter_data["provider_lastname"]
        if first_name.present? && last_name.present?
          provider = Provider.joins(:organizations)
                            .where(
                              first_name: first_name,
                              last_name: last_name,
                              organizations: { id: organization_id }
                            )
                            .first
          return provider if provider
        end

        nil
      end

      def find_specialty_for_encounter(encounter_data)
        # Try specialty name
        specialty_name = encounter_data["specialty"] || encounter_data["specialty_name"]
        if specialty_name.present?
          specialty = Specialty.where("name ILIKE ?", "%#{specialty_name}%").first
          return specialty if specialty
        end

        # Try specialty_id from EZclaim
        specialty_id = encounter_data["specialty_id"]
        if specialty_id.present?
          specialty = Specialty.find_by(id: specialty_id)
          return specialty if specialty
        end

        # Try specialty code
        specialty_code = encounter_data["specialty_code"]
        if specialty_code.present?
          specialty = Specialty.where("code ILIKE ?", "%#{specialty_code}%").first
          return specialty if specialty
        end

        nil
      end

      def determine_billing_channel(encounter_data)
        # Check if insurance billing is indicated
        if encounter_data["billing_channel"].present?
          channel = encounter_data["billing_channel"].to_s.downcase
          return :insurance if channel.include?("insurance")
          return :self_pay if channel.include?("self") || channel.include?("pay")
        end

        # Check if patient_insurance_coverage_id is present
        if encounter_data["patient_insurance_coverage_id"].present? || encounter_data["insurance_coverage_id"].present?
          return :insurance
        end

        # Default to self_pay
        :self_pay
      end

      def build_encounter_attributes(encounter_data:, organization_id:, patient_id:, provider_id:, specialty_id:, date_of_service:, billing_channel:)
        {
          organization_id: organization_id,
          patient_id: patient_id,
          provider_id: provider_id,
          specialty_id: specialty_id,
          date_of_service: date_of_service,
          billing_channel: billing_channel,
          status: :planned,
          notes: encounter_data["notes"] || encounter_data["note"] || nil,
          organization_location_id: find_organization_location(encounter_data, organization_id)
        }
      end

      def find_organization_location(encounter_data, organization_id)
        location_id = encounter_data["organization_location_id"] || encounter_data["location_id"]
        if location_id.present?
          location = OrganizationLocation.find_by(id: location_id, organization_id: organization_id)
          return location&.id if location
        end

        # Try by name
        location_name = encounter_data["location_name"] || encounter_data["location"]
        if location_name.present?
          location = OrganizationLocation.where(
            "name ILIKE ? AND organization_id = ?",
            "%#{location_name}%",
            organization_id
          ).first
          return location&.id if location
        end

        nil
      end

      def skip_item(reason)
        {
          find_by: {},
          attributes: {},
          skip: true,
          skip_reason: reason
        }
      end
    end
  end
end

class WaystarEdiSubmissionService
  # Main service that combines EDI generation and SFTP upload to Waystar

  attr_reader :encounters, :organization, :errors

  def initialize(encounters:, organization:)
    @encounters = Array(encounters)
    @organization = organization
    @errors = []
  end

  def submit
    return { success: false, error: "No encounters provided" } if @encounters.empty?
    return { success: false, error: "Organization not provided" } unless @organization

    # Step 1: Generate EDI 837 file directly from encounters (no claims needed)
    edi_service = Edi837GenerationService.new(
      encounters: @encounters,
      organization: @organization
    )

    edi_result = edi_service.generate
    unless edi_result[:success]
      return { success: false, error: "EDI Generation failed: #{edi_result[:error]}" }
    end

    # Step 2: Save to temporary file
    file_result = edi_service.generate_and_save_to_file
    unless file_result[:success]
      return { success: false, error: "File creation failed: #{file_result[:error]}" }
    end

    # File successfully created - store file info for return value
    # Status updates will happen in the job after confirming file creation
    base_result = {
      success: true,
      filename: file_result[:filename],
      edi_file_path: file_result[:file_path], # Always include file path when file is created
      transaction_count: edi_result[:transaction_count]
    }

    # Step 3: Handle based on environment
    if Rails.env.development? || Rails.env.test?
      # LOCAL: Create claims after EDI generation (for testing/record keeping)
      created_claims = create_claims_from_encounters
      unless created_claims[:success]
        # Claim creation failed, but file was created - return with file path
        # Status update will happen in job based on file creation success
        return base_result.merge(
          success: false,
          error: "Claim creation failed: #{created_claims[:error]}"
        )
      end

      # In development, keep the file in public/ for inspection
      # In production, clean up temp file
      if Rails.env.production?
        File.delete(file_result[:file_path]) if File.exist?(file_result[:file_path])
      end

      base_result.merge(
        created_claims: created_claims[:created_claims]
      )
    else
      # PRODUCTION: Submit to Waystar first, then create claims only on success
      sftp_service = WaystarSftpService.new(organization: @organization)
      upload_result = sftp_service.upload_file(
        file_result[:file_path],
        file_result[:filename]
      )

      unless upload_result[:success]
        # SFTP failed, but file was created - return error with file path
        # Don't delete file - status update will happen in job based on file creation
        # File can be manually inspected or retried
        return base_result.merge(
          success: false,
          error: "SFTP Upload failed: #{upload_result[:error]}"
        )
      end

      # Only create claims after successful submission (for record keeping)
      created_claims = create_claims_from_encounters
      unless created_claims[:success]
        # Log warning but don't fail - file was already submitted
        Rails.logger.warn("Claim creation failed after successful submission: #{created_claims[:error]}")
      end

      # Create claim submission records (for tracking)
      update_claim_submissions(upload_result)

      # Clean up temp file on success
      File.delete(file_result[:file_path]) if File.exist?(file_result[:file_path])

      base_result.merge(
        remote_path: upload_result[:remote_path],
        uploaded_at: upload_result[:uploaded_at],
        created_claims: created_claims[:created_claims] || []
      )
    end
  rescue => e
    Rails.logger.error "Waystar EDI Submission Error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    { success: false, error: e.message }
  end

  private

  def create_claims_from_encounters
    created_claims = []
    errors = []

    @encounters.each do |encounter|
      # Check if claim already exists (check both association and database directly)
      # Reload encounter to ensure association is fresh
      encounter.reload if encounter.claim_id.present?

      existing_claim = Claim.find_by(encounter_id: encounter.id)
      if existing_claim.present?
        # If claim exists and has claim lines, use it as-is
        if existing_claim.claim_lines.any?
          created_claims << existing_claim
          # Ensure encounter is linked to the claim
          encounter.update_column(:claim_id, existing_claim.id) unless encounter.claim_id == existing_claim.id
          next
        else
          # Claim exists but has no lines - we'll recreate the lines below
          # Delete the empty claim first to avoid conflicts
          existing_claim.destroy
        end
      end

      begin
        # Check for procedure codes first
        procedure_items = encounter.encounter_procedure_items.includes(:procedure_code)

        if procedure_items.empty?
          errors << "Encounter #{encounter.id}: No procedure codes found"
          next
        end

        # Build claim record (don't save yet - we need to add lines first)
        claim = Claim.new(
          organization_id: encounter.organization_id,
          encounter_id: encounter.id,
          patient_id: encounter.patient_id,
          provider_id: encounter.provider_id,
          specialty_id: encounter.specialty_id,
          patient_insurance_coverage_id: encounter.patient_insurance_coverage_id,
          place_of_service_code: encounter.organization_location&.place_of_service_code || "11",
          status: :generated,
          generated_at: Time.current
        )

        # Create claim lines from encounter procedure codes
        procedure_items.each do |item|
          procedure_code = item.procedure_code

          # Get pricing from fee schedule
          pricing_result = FeeSchedulePricingService.resolve_pricing(
            encounter.organization_id,
            encounter.provider_id,
            procedure_code.id
          )

          # Calculate units and amount
          unit_price = pricing_result[:success] ? pricing_result[:pricing][:unit_price].to_f : 0.0
          pricing_rule = pricing_result[:success] ? pricing_result[:pricing][:pricing_rule] : "flat"

          # For now, default to 1 unit (can be enhanced based on duration if needed)
          units = 1

          # Calculate amount billed based on pricing rule
          amount_billed = if pricing_rule == "flat"
            unit_price
          else
            unit_price * units
          end

          # Get diagnosis pointers (first 4 diagnosis codes)
          diagnosis_codes = encounter.diagnosis_codes.limit(4).pluck(:id)
          dx_pointers = diagnosis_codes.map.with_index { |_, idx| idx + 1 }

          # Build claim line (don't save yet)
          claim.claim_lines.build(
            procedure_code_id: procedure_code.id,
            units: units,
            amount_billed: amount_billed,
            place_of_service_code: encounter.organization_location&.place_of_service_code || "11",
            dx_pointers_numeric: dx_pointers,
            status: :generated
          )
        end

        # Now save the claim with all lines (validation will pass since lines exist)
        begin
          unless claim.save
            # Check if the error is due to duplicate encounter_id (claim already exists)
            if claim.errors[:encounter_id].include?("DUPLICATE_CLAIM_FOR_ENCOUNTER")
              # Claim already exists for this encounter, find and use it
              existing_claim = Claim.find_by(encounter_id: encounter.id)
              if existing_claim.present?
                created_claims << existing_claim
                encounter.update_column(:claim_id, existing_claim.id) unless encounter.claim_id == existing_claim.id
                next
              end
            end
            errors << "Encounter #{encounter.id}: Validation failed: #{claim.errors.full_messages.join(', ')}"
            next
          end
        rescue ActiveRecord::RecordNotUnique => e
          # Handle primary key sequence issues
          if e.message.include?("claim_lines_pkey") || e.message.include?("claims_pkey")
            # Reset the sequence and retry once
            Rails.logger.warn("Sequence out of sync for encounter #{encounter.id}, attempting to fix...")
            begin
              # Reset claim_lines sequence
              ActiveRecord::Base.connection.execute("SELECT setval(pg_get_serial_sequence('claim_lines', 'id'), COALESCE((SELECT MAX(id) FROM claim_lines), 1), true)")
              # Reset claims sequence
              ActiveRecord::Base.connection.execute("SELECT setval(pg_get_serial_sequence('claims', 'id'), COALESCE((SELECT MAX(id) FROM claims), 1), true)")

              # Retry saving
              if claim.save
                encounter.update_column(:claim_id, claim.id)
                created_claims << claim
                next
              else
                errors << "Encounter #{encounter.id}: Failed to save after sequence reset: #{claim.errors.full_messages.join(', ')}"
                next
              end
            rescue => retry_error
              errors << "Encounter #{encounter.id}: Sequence reset failed: #{retry_error.message}"
              next
            end
          else
            raise e
          end
        end

        # Update encounter to reference the claim
        encounter.update_column(:claim_id, claim.id)

        # Note: EDI file path will be saved in the job after file creation
        # This ensures the file exists before we reference it

        created_claims << claim
      rescue => e
        Rails.logger.error("Error creating claim for encounter #{encounter.id}: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
        errors << "Encounter #{encounter.id}: #{e.message}"
      end
    end

    if errors.any?
      {
        success: false,
        error: errors.join("; "),
        created_claims: created_claims
      }
    else
      {
        success: true,
        created_claims: created_claims
      }
    end
  end

  def update_claim_submissions(upload_result)
    @encounters.each do |encounter|
      next unless encounter.claim.present?

      claim = encounter.claim

      # Create or update claim submission record
      submission = claim.claim_submissions.find_or_initialize_by(
        submission_method: :sftp,
        external_submission_key: upload_result[:filename]
      )

      submission.assign_attributes(
        organization: @organization,
        patient: encounter.patient,
        submitted_at: upload_result[:uploaded_at],
        status: :submitted,
        ack_status: :pending,
        submission_payload: {
          filename: upload_result[:filename],
          remote_path: upload_result[:remote_path],
          transaction_count: upload_result[:transaction_count]
        }
      )

      submission.save if submission.changed?
    end
  end
end

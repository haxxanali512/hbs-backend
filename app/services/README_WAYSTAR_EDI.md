# Waystar EDI 837 Submission Service

This service generates HIPAA-compliant 837P EDI files from encounters/claims and uploads them to Waystar via SFTP.

## Services

### 1. `Edi837GenerationService`
Generates X12 837P EDI files from encounters/claims.

**Usage:**
```ruby
encounters = Encounter.where(status: :ready_to_submit).limit(10)
organization = Organization.find(1)

service = Edi837GenerationService.new(
  encounters: encounters,
  organization: organization
)

# Generate EDI content
result = service.generate
if result[:success]
  puts "Generated #{result[:transaction_count]} transactions"
  puts "Filename: #{result[:filename]}"
  puts "Content length: #{result[:content].length} bytes"
end

# Generate and save to file
file_result = service.generate_and_save_to_file
if file_result[:success]
  puts "File saved to: #{file_result[:file_path]}"
end
```

### 2. `WaystarSftpService`
Handles SFTP uploads to Waystar.

**Usage:**
```ruby
organization = Organization.find(1)
sftp_service = WaystarSftpService.new(organization: organization)

# Test connection
test_result = sftp_service.test_connection
puts test_result[:success] ? "Connected!" : "Failed: #{test_result[:error]}"

# Upload file
upload_result = sftp_service.upload_file("/path/to/file.edi", "837P_123_20250101.edi")
if upload_result[:success]
  puts "Uploaded to: #{upload_result[:remote_path]}"
end

# Upload content directly
upload_result = sftp_service.upload_content(edi_content, "837P_123_20250101.edi")
```

### 3. `WaystarEdiSubmissionService` (Main Service)
Combines EDI generation and SFTP upload in one service.

**Usage:**
```ruby
encounters = Encounter.where(status: :ready_to_submit).limit(10)
organization = Organization.find(1)

service = WaystarEdiSubmissionService.new(
  encounters: encounters,
  organization: organization
)

result = service.submit

if result[:success]
  puts "Successfully submitted!"
  puts "Filename: #{result[:filename]}"
  puts "Remote path: #{result[:remote_path]}"
  puts "Transactions: #{result[:transaction_count]}"
  puts "Uploaded at: #{result[:uploaded_at]}"
else
  puts "Error: #{result[:error]}"
end
```

## Configuration

### Waystar SFTP Settings

The service looks for configuration in this order:
1. Rails credentials (`config/credentials/production.yml.enc`)
2. Environment variables
3. Organization settings (if columns are added)

#### Rails Credentials (Recommended)
```yaml
waystar:
  sftp_host: "sftp.waystar.com"
  sftp_username: "your_username"
  sftp_password: "your_password"
  sftp_port: 22
  sftp_remote_directory: "/incoming"
  sftp_verify_host_key: "never" # or "always"
```

Edit credentials:
```bash
EDITOR="code --wait" rails credentials:edit --environment production
```

#### Environment Variables
```bash
WAYSTAR_SFTP_HOST=sftp.waystar.com
WAYSTAR_SFTP_USERNAME=your_username
WAYSTAR_SFTP_PASSWORD=your_password
WAYSTAR_SFTP_PORT=22
WAYSTAR_SFTP_REMOTE_DIRECTORY=/incoming
WAYSTAR_SFTP_VERIFY_HOST_KEY=never
```

## EDI 837P Structure

The service generates HIPAA-compliant X12 837P (Professional) files with the following structure:

- **ISA/GS/ST** - Interchange, Group, and Transaction Headers
- **BHT** - Beginning of Hierarchical Transaction
- **Loop 2000A** - Billing Provider Information
- **Loop 2000B** - Subscriber/Patient Information
- **Loop 2300** - Claim Information
  - CLM - Claim Information
  - DTP - Date of Service
  - HI - Diagnosis Codes
  - NM1 - Rendering Provider
- **Loop 2400** - Service Lines
  - LX - Service Line Number
  - SV1 - Professional Service
  - DTP - Service Date
- **SE/GE/IEA** - Transaction, Group, and Interchange Trailers

## Example: Batch Submission Job

```ruby
class WaystarSubmissionJob < ApplicationJob
  queue_as :default

  def perform(organization_id, encounter_ids)
    organization = Organization.find(organization_id)
    encounters = Encounter.where(id: encounter_ids, organization: organization)
    
    service = WaystarEdiSubmissionService.new(
      encounters: encounters,
      organization: organization
    )
    
    result = service.submit
    
    if result[:success]
      Rails.logger.info "Successfully submitted #{result[:transaction_count]} transactions to Waystar"
      encounters.update_all(status: :sent)
    else
      Rails.logger.error "Waystar submission failed: #{result[:error]}"
      raise StandardError, result[:error]
    end
  end
end
```

## Notes

- The service automatically creates `ClaimSubmission` records to track submissions
- Temporary EDI files are automatically cleaned up after successful upload
- The service supports both insurance and self-pay encounters
- Diagnosis codes are limited to 12 per claim (HIPAA standard)
- All monetary amounts are formatted to 2 decimal places
- Dates are formatted as YYYYMMDD or YYMMDD per EDI standards


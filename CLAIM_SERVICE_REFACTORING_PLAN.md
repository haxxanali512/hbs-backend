# Claim Service Refactoring Plan

## Overview
Refactor the claims system to move claim payload building from Claim model/controllers to a dedicated service that builds claims from Encounters. The flow should be: **Encounter → Build Claim Payload → POST Claim → Attach Service Lines → Track Submission**.

## Current State Analysis

### What Exists:
1. **Claim Model**: Stores claim data, has `build_claim_payload` methods in controllers
2. **Claim Controllers**: Both admin and tenant have:
   - `claim_data` - builds payload for preview
   - `submit_claim` - submits claim to EZClaim
   - `build_claim_payload` - private method to build payload
   - `build_claim_insured_payload` - private method for claim insured
3. **EZClaim Service**: Has `create_claim` method that POSTs to `/Claims` endpoint
4. **EZClaim Buttons**: Shared partial `_ezclaim_buttons.html.erb` used in claims show pages
5. **Claim Lines**: Stored in `claim_lines` table, linked to procedure codes

### What Needs to Change:
1. Remove payload building from Claim controllers
2. Create dedicated `ClaimSubmissionService` that builds payloads from Encounters
3. Move "Submit for Billing" button from Claims show page to Encounters show page
4. Implement Service Lines API integration (user will provide API details)
5. Update Claim model to be a storage/response record only

## Implementation Steps

### Phase 1: Create Claim Submission Service

#### Step 1.1: Create `ClaimSubmissionService`
**File**: `app/services/claim_submission_service.rb`

**Responsibilities**:
- Build claim payload from encounter data
- Build service lines payload from encounter procedure items
- Submit claim to EZClaim API
- Submit service lines to Service Lines API
- Create Claim record with response data
- Create ClaimSubmission record
- Handle errors and rollback

**Methods**:
```ruby
class ClaimSubmissionService
  def initialize(encounter:, organization:)
    @encounter = encounter
    @organization = organization
  end

  def submit_for_billing
    # 1. Validate encounter is ready
    # 2. Build claim payload
    # 3. POST to EZClaim /Claims endpoint
    # 4. Get claim_id from response
    # 5. Build service lines payload
    # 6. POST service lines to Service Lines API
    # 7. Create Claim record with response data
    # 8. Create ClaimSubmission record
    # 9. Return result
  end

  private

  def build_claim_payload
    # Build from encounter:
    # - Patient FID
    # - Provider FID (rendering and billing)
    # - Diagnosis codes
    # - Date of service
    # - Submission method
  end

  def build_service_lines_payload(claim_id)
    # Build from encounter procedure items:
    # - Claim FID (from step 4)
    # - Procedure codes
    # - Units
    # - Dates
    # - Modifiers (if available)
  end

  def validate_encounter_ready
    # Check:
    # - Encounter is completed_confirmed
    # - Has diagnosis codes
    # - Has procedure items
    # - EZClaim enabled
  end
end
```

#### Step 1.2: Add Service Lines API to EzclaimService
**File**: `app/services/ezclaim_service.rb`

**Add method**:
```ruby
def create_service_lines(service_lines_data)
  # POST to Service Lines endpoint
  # User will provide exact endpoint and payload format
  make_request(:post, "/ServiceLines", params: service_lines_data)
end
```

### Phase 2: Update Encounter Controller

#### Step 2.1: Add `submit_for_billing` action
**Files**: 
- `app/controllers/tenant/encounters_controller.rb`
- `app/controllers/admin/encounters_controller.rb`

**Action**:
```ruby
def submit_for_billing
  service = ClaimSubmissionService.new(
    encounter: @encounter,
    organization: current_organization
  )
  
  result = service.submit_for_billing
  
  if result[:success]
    redirect_to tenant_encounter_path(@encounter), 
                notice: "Encounter submitted for billing successfully."
  else
    redirect_to tenant_encounter_path(@encounter), 
                alert: "Failed to submit: #{result[:error]}"
  end
end
```

#### Step 2.2: Add route
**File**: `config/routes.rb`

```ruby
# In tenant namespace
resources :encounters do
  member do
    post :submit_for_billing
  end
end

# In admin namespace
resources :encounters do
  member do
    post :submit_for_billing
  end
end
```

#### Step 2.3: Add button to Encounter show page
**Files**:
- `app/views/tenant/encounters/show.html.erb`
- `app/views/admin/encounters/show.html.erb`

**Add button** (similar to "Confirm Completed"):
```erb
<% if @encounter.completed_confirmed? && @encounter.organization.organization_setting&.ezclaim_enabled? && !@encounter.claim %>
  <%= button_to "Submit for Billing", 
      submit_for_billing_tenant_encounter_path(@encounter), 
      method: :post,
      class: "bg-green-600 hover:bg-green-700 text-white font-medium py-2 px-4 rounded-lg transition-colors",
      data: { confirm: "This will submit the encounter to EZClaim for billing. Continue?" } %>
<% end %>
```

### Phase 3: Remove Payload Building from Claims

#### Step 3.1: Remove methods from Claim controllers
**Files**:
- `app/controllers/admin/claims_controller.rb`
- `app/controllers/tenant/claims_controller.rb`

**Remove**:
- `claim_data` action
- `submit_claim` action
- `claim_insured_data` action
- `submit_claim_insured` action
- `build_claim_payload` private method
- `build_claim_insured_payload` private method
- `build_ezclaim_payload_preview` private method
- `claim_params_for_ezclaim` private method
- `claim_insured_params` private method
- `map_relationship_to_insured` private method
- `map_coverage_order` private method

#### Step 3.2: Remove EZClaim buttons from Claims show pages
**Files**:
- `app/views/admin/claims/show.html.erb`
- `app/views/tenant/claims/show.html.erb`

**Remove**:
- The `render 'shared/ezclaim_buttons'` partial
- The entire Actions section that contains EZClaim buttons

#### Step 3.3: Remove routes
**File**: `config/routes.rb`

**Remove from both admin and tenant**:
```ruby
member do
  get :claim_insured_data
  post :submit_claim_insured
  get :claim_data
  post :submit_claim
end
```

### Phase 4: Update Claim Model

#### Step 4.1: Update Claim to be response storage only
**File**: `app/models/claim.rb`

**Changes**:
- Remove any methods that build payloads
- Add methods to store response data:
  - `external_claim_key` (already exists)
  - Store full response JSON if needed
  - Store claim_id from EZClaim response

**Note**: Claim should now be created AFTER successful API submission, not before.

### Phase 5: Update EZClaim Service

#### Step 5.1: Add Service Lines endpoint
**File**: `app/services/ezclaim_service.rb`

**Add**:
```ruby
def create_service_lines(service_lines_data)
  # User will provide exact endpoint
  # Likely: POST /ServiceLines or /Claims/{claim_id}/ServiceLines
  make_request(:post, "/ServiceLines", params: service_lines_data)
end
```

**Note**: Wait for user to provide exact API endpoint and payload format.

### Phase 6: Handle Encounter Procedure Items

#### Step 6.1: Determine how procedure items are stored
**Current State**: `encounter_procedure_items` table exists but model is placeholder

**Options**:
1. If encounter_procedure_items table has data:
   - Use existing table
   - Build service lines from `encounter_procedure_items`
2. If not implemented yet:
   - May need to use a different source (encounter form, claim_lines if they exist)
   - Or implement encounter_procedure_items first

**Action**: Check database schema and existing data to determine approach.

### Phase 7: Testing & Validation

#### Step 7.1: Test flow
1. Create encounter with diagnosis codes and procedure items
2. Mark encounter as completed_confirmed
3. Click "Submit for Billing"
4. Verify:
   - Claim payload is built correctly
   - Claim is POSTed to EZClaim
   - Claim ID is received
   - Service lines are POSTed
   - Claim record is created with response data
   - ClaimSubmission record is created

#### Step 7.2: Error handling
- Handle API failures gracefully
- Rollback if service lines fail after claim succeeds
- Store error messages
- Allow retry mechanism

## Files to Create

1. `app/services/claim_submission_service.rb` - Main service
2. Update `app/services/ezclaim_service.rb` - Add service lines method

## Files to Modify

1. `app/controllers/tenant/encounters_controller.rb` - Add submit_for_billing
2. `app/controllers/admin/encounters_controller.rb` - Add submit_for_billing
3. `app/views/tenant/encounters/show.html.erb` - Add button
4. `app/views/admin/encounters/show.html.erb` - Add button
5. `app/controllers/tenant/claims_controller.rb` - Remove payload methods
6. `app/controllers/admin/claims_controller.rb` - Remove payload methods
7. `app/views/tenant/claims/show.html.erb` - Remove EZClaim buttons
8. `app/views/admin/claims/show.html.erb` - Remove EZClaim buttons
9. `config/routes.rb` - Update routes
10. `app/models/claim.rb` - Update if needed

## Files to Remove/Deprecate

1. `app/views/shared/_ezclaim_buttons.html.erb` - May keep for future use or remove
2. Payload building methods from controllers

## Questions for User

1. **Service Lines API**: What is the exact endpoint and payload format?
2. **Encounter Procedure Items**: How are procedure codes, units, and fees stored for an encounter? Is `encounter_procedure_items` table populated?
3. **Claim Creation Timing**: Should Claim record be created:
   - Before API call (with status: generated)?
   - After successful API call (with response data)?
4. **Error Handling**: If service lines fail after claim succeeds, should we:
   - Rollback the claim?
   - Mark claim as partial?
   - Allow manual retry?
5. **Claim Insured**: Should we still support Claim Insured submission, or is that handled differently now?

## Next Steps

1. Wait for user to provide Service Lines API details
2. Confirm how encounter procedure items are stored
3. Start implementing Phase 1 (ClaimSubmissionService)
4. Test with sample encounter data
5. Iterate based on API responses


module ActivationStepsConcern
  extend ActiveSupport::Concern

  def build_detailed_activation_steps(organization)
    checklist = organization.activation_checklist || organization.build_activation_checklist
    accepted_plans = organization.org_accepted_plans.active_only.current.includes(:insurance_plan)
    accepted_plans.each do |plan|
      OrganizationActivationPlanStep.step_types.keys.each do |step|
        OrganizationActivationPlanStep.find_or_create_by!(
          org_accepted_plan_id: plan.id,
          step_type: step
        )
      end
    end

    plan_step_scope = OrganizationActivationPlanStep.where(org_accepted_plan_id: accepted_plans.select(:id))
    plan_steps_by_type = plan_step_scope.group_by(&:step_type)

    steps = [
      {
        name: "Form Completion",
        substeps: [
          { name: "Contracts and form signatures completed", completed: organization.compliance_signed?, auto: true }
        ]
      },
      {
        name: "Organization Setup",
        substeps: organization_setup_substeps(organization)
      },
      {
        name: "Internal System Setup",
        substeps: [
          { name: "Create Waystar Child Account", completed: checklist.waystar_child_account_completed, manual: true },
          build_plan_substeps(
            "Complete enrollments for accepted plans",
            plan_steps_by_type["waystar_enrollment"],
            available: checklist.waystar_child_account_completed
          ),
          { name: "Create EZClaim Record or alternative billing software record", completed: checklist.ezclaim_record_completed, manual: true },
          build_plan_substeps(
            "Initiate Payer Enrollments for Accepted Plans",
            plan_steps_by_type["payer_enrollment"]
          )
        ]
      },
      {
        name: "Initial Encounter",
        substeps: [
          { name: "Client prepares an initial encounter", completed: organization.initial_encounter_prepared?, auto: true },
          { name: "HBS bills initial encounter", completed: checklist.initial_encounter_billed_completed, manual: true },
          { name: "HBS executes a name match in Waystar", completed: checklist.name_match_completed, manual: true }
        ]
      },
      {
        name: "Enrollment Completion",
        substeps: [
          build_plan_substeps(
            "Verify payer/s are accepting claims for Organization",
            plan_steps_by_type["payer_accepting_claims"]
          ),
          build_plan_substeps(
            "Verify waystar is receiving remits from payer/s",
            plan_steps_by_type["waystar_receiving_remits"]
          )
        ]
      }
    ]

    steps.map { |step| apply_step_status(step) }
  end

  def organization_setup_substeps(organization)
    [
      {
        name: "Address (at least Billing address)",
        completed: organization.has_billing_address?,
        auto: true,
        action_path: nil # Removed for admin view - informational only
      },
      {
        name: "Specialty (at least 1)",
        completed: organization.has_active_specialties?,
        auto: true,
        action_path: nil # Removed for admin view - informational only
      },
      {
        name: "Fee schedule for any selected Specialties",
        completed: organization.has_fee_schedule_items?,
        auto: true,
        action_path: nil # Removed for admin view - informational only
      },
      {
        name: "Provider (at least 1)",
        completed: organization.has_active_providers?,
        auto: true,
        action_path: nil # Removed for admin view - informational only
      },
      {
        name: "Accepted Plans (at least 1)",
        completed: organization.has_accepted_plans?,
        auto: true,
        action_path: nil # Removed for admin view - informational only
      }
    ]
  end

  def build_plan_substeps(label, plan_steps, available: true)
    items = Array(plan_steps).map do |step|
      {
        name: step.org_accepted_plan&.insurance_plan&.name || "Accepted Plan",
        completed: step.completed
      }
    end

    {
      name: label,
      available: available,
      items: items,
      manual: true # Plan-based steps are HBS tasks
    }
  end

  def apply_step_status(step)
    total, completed = count_step_items(step)
    status =
      if total.zero?
        :not_started
      elsif completed.zero?
        :not_started
      elsif completed < total
        :in_progress
      else
        :completed
      end

    step.merge(status: status, completed_items: completed, total_items: total)
  end

  def count_step_items(step)
    total = 0
    completed = 0

    Array(step[:substeps]).each do |sub|
      if sub[:items].present? && sub[:available] != false
        total += sub[:items].size
        completed += sub[:items].count { |item| item[:completed] }
      else
        total += 1
        completed += 1 if sub[:completed]
      end
    end

    [ total, completed ]
  end
end

module PatientVisitStats
  extend ActiveSupport::Concern

  # Get visit count per calendar year by service type (specialty) for this patient
  # Returns a hash: { year => { specialty_id => count } }
  # Example: { 2024 => { 1 => 5, 2 => 3 }, 2023 => { 1 => 2 } }
  def visit_count_by_year_and_specialty
    # Count encounters that are considered "visits" (not cancelled, not planned)
    # Adjust statuses based on your business logic
    visit_statuses = [ :ready_for_review, :reviewed, :ready_to_submit, :completed_confirmed, :sent ]

    encounters
      .kept
      .where(status: visit_statuses)
      .where.not(date_of_service: nil)
      .group("EXTRACT(YEAR FROM date_of_service)", "specialty_id")
      .count
      .each_with_object({}) do |((year, specialty_id), count), hash|
        year_int = year.to_i
        hash[year_int] ||= {}
        hash[year_int][specialty_id] = count
      end
  end

  # Get visit count for a specific year and specialty
  def visit_count_for_year_and_specialty(year:, specialty_id:)
    visit_statuses = [ :ready_for_review, :reviewed, :ready_to_submit, :completed_confirmed, :sent ]

    encounters
      .kept
      .where(status: visit_statuses)
      .where(specialty_id: specialty_id)
      .where("EXTRACT(YEAR FROM date_of_service) = ?", year)
      .count
  end

  # Get visit count for current calendar year by specialty
  def current_year_visit_count_by_specialty
    current_year = Date.current.year
    visit_count_by_year_and_specialty[current_year] || {}
  end

  # Get total visit count for a specific year
  def total_visits_for_year(year)
    visit_statuses = [ :ready_for_review, :reviewed, :ready_to_submit, :completed_confirmed, :sent ]

    encounters
      .kept
      .where(status: visit_statuses)
      .where("EXTRACT(YEAR FROM date_of_service) = ?", year)
      .count
  end

  # Get visit count for a specific specialty (all years)
  def total_visits_for_specialty(specialty_id)
    visit_statuses = [ :ready_for_review, :reviewed, :ready_to_submit, :completed_confirmed, :sent ]

    encounters
      .kept
      .where(status: visit_statuses)
      .where(specialty_id: specialty_id)
      .count
  end
end

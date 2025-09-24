require "test_helper"

class Api::V1::FileUploadsControllerTest < ActionDispatch::IntegrationTest
  test "should create file upload" do
    file = fixture_file_upload("test.csv", "text/csv")

    post api_v1_file_uploads_path, params: { file: file }

    assert_response :accepted
    response_data = JSON.parse(response.body)
    assert_equal "File uploaded successfully and processing started", response_data["message"]
    assert response_data["job_id"].present?
    assert_equal "csv", response_data["file_type"]
    assert_equal "queued", response_data["status"]
  end

  test "should reject file without file parameter" do
    post api_v1_file_uploads_path

    assert_response :bad_request
    response_data = JSON.parse(response.body)
    assert_equal "No file provided", response_data["error"]
  end

  test "should reject file with invalid type" do
    file = fixture_file_upload("test.txt", "text/plain")

    post api_v1_file_uploads_path, params: { file: file }

    assert_response :unprocessable_entity
    response_data = JSON.parse(response.body)
    assert_equal "Invalid file type", response_data["error"]
  end

  test "should get job status" do
    job_id = "test-job-id"
    get status_api_v1_file_uploads_path, params: { job_id: job_id }

    assert_response :ok
    response_data = JSON.parse(response.body)
    assert_equal job_id, response_data["job_id"]
    assert response_data["status"].present?
  end

  test "should reject status request without job_id" do
    get status_api_v1_file_uploads_path

    assert_response :bad_request
    response_data = JSON.parse(response.body)
    assert_equal "Job ID is required", response_data["error"]
  end
end

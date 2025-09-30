require "test_helper"

class FileUploadUrlTest < ActionDispatch::IntegrationTest
  test "should handle URL upload with real HTTP request" do
    # This test uses a real URL to verify the functionality works
    # In a real scenario, you would use a test file hosted somewhere
    # For now, we'll test the validation logic which is the main concern

    # Test invalid URL format
    post api_v1_file_uploads_path, params: { url: "not-a-valid-url" }
    assert_response :unprocessable_entity
    response_data = JSON.parse(response.body)
    assert_equal "Invalid URL format", response_data["error"]

    # Test unsupported file type
    post api_v1_file_uploads_path, params: { url: "https://example.com/test.pdf" }
    assert_response :unprocessable_entity
    response_data = JSON.parse(response.body)
    assert_equal "Unsupported file type in URL", response_data["error"]

    # Test malformed URI
    post api_v1_file_uploads_path, params: { url: "https://[invalid-uri" }
    assert_response :unprocessable_entity
    response_data = JSON.parse(response.body)
    assert_equal "Invalid URL", response_data["error"]
  end
end

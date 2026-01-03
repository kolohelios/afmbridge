import XCTest

@testable import DTOs

final class ErrorResponseTests: XCTestCase {

    // MARK: - OpenAI Error Response Tests

    func testOpenAIErrorResponse_encoding() throws {
        let error = OpenAIError(
            message: "Invalid request", type: "invalid_request_error", param: "model",
            code: "invalid_model")
        let response = OpenAIErrorResponse(error: error)

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(response)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(json)
        let errorObj = json?["error"] as? [String: Any]
        XCTAssertEqual(errorObj?["message"] as? String, "Invalid request")
        XCTAssertEqual(errorObj?["type"] as? String, "invalid_request_error")
        XCTAssertEqual(errorObj?["param"] as? String, "model")
        XCTAssertEqual(errorObj?["code"] as? String, "invalid_model")
    }

    func testOpenAIErrorResponse_decoding() throws {
        let json = """
            {
                "error": {
                    "message": "Model not found",
                    "type": "model_not_found",
                    "param": null,
                    "code": null
                }
            }
            """

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(OpenAIErrorResponse.self, from: json.data(using: .utf8)!)

        XCTAssertEqual(response.error.message, "Model not found")
        XCTAssertEqual(response.error.type, "model_not_found")
        XCTAssertNil(response.error.param)
        XCTAssertNil(response.error.code)
    }

    func testOpenAIError_minimalFields() {
        let error = OpenAIError(message: "Error occurred", type: "api_error")

        XCTAssertEqual(error.message, "Error occurred")
        XCTAssertEqual(error.type, "api_error")
        XCTAssertNil(error.param)
        XCTAssertNil(error.code)
    }

    // MARK: - Anthropic Error Response Tests

    func testAnthropicErrorResponse_encoding() throws {
        let error = AnthropicError(type: "invalid_request_error", message: "Missing required field")
        let response = AnthropicErrorResponse(error: error)

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(response)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(json)
        XCTAssertEqual(json?["type"] as? String, "error")
        let errorObj = json?["error"] as? [String: Any]
        XCTAssertEqual(errorObj?["type"] as? String, "invalid_request_error")
        XCTAssertEqual(errorObj?["message"] as? String, "Missing required field")
    }

    func testAnthropicErrorResponse_decoding() throws {
        let json = """
            {
                "type": "error",
                "error": {
                    "type": "api_error",
                    "message": "Service unavailable"
                }
            }
            """

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(
            AnthropicErrorResponse.self, from: json.data(using: .utf8)!)

        XCTAssertEqual(response.type, "error")
        XCTAssertEqual(response.error.type, "api_error")
        XCTAssertEqual(response.error.message, "Service unavailable")
    }

    func testAnthropicErrorResponse_typeIsAlwaysError() {
        let error = AnthropicError(type: "validation_error", message: "Invalid input")
        let response = AnthropicErrorResponse(error: error)

        XCTAssertEqual(response.type, "error")
    }

    // MARK: - Error Type Consistency Tests

    func testErrorTypes_matchAPISpecifications() {
        // Test common error types used in both APIs
        let openAIError = OpenAIError(message: "Test", type: "invalid_request_error")
        let anthropicError = AnthropicError(type: "invalid_request_error", message: "Test")

        // Both APIs should support these common error types
        XCTAssertEqual(openAIError.type, "invalid_request_error")
        XCTAssertEqual(anthropicError.type, "invalid_request_error")
    }
}

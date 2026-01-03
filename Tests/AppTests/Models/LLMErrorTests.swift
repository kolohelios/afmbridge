import XCTest

@testable import Models

/// Tests for LLMError types and error descriptions
final class LLMErrorTests: XCTestCase {

    // MARK: - Error Case Tests

    func testModelNotAvailable_createsCorrectError() {
        let error = LLMError.modelNotAvailable("gpt-4")

        if case .modelNotAvailable(let model) = error {
            XCTAssertEqual(model, "gpt-4")
        } else {
            XCTFail("Expected modelNotAvailable error")
        }
    }

    func testFrameworkNotAvailable_createsCorrectError() {
        let error = LLMError.frameworkNotAvailable

        if case .frameworkNotAvailable = error {
            // Success
        } else {
            XCTFail("Expected frameworkNotAvailable error")
        }
    }

    func testInvalidMessageFormat_createsCorrectError() {
        let error = LLMError.invalidMessageFormat("Empty messages array")

        if case .invalidMessageFormat(let message) = error {
            XCTAssertEqual(message, "Empty messages array")
        } else {
            XCTFail("Expected invalidMessageFormat error")
        }
    }

    func testContentFiltered_createsCorrectError() {
        let error = LLMError.contentFiltered("Inappropriate content detected")

        if case .contentFiltered(let reason) = error {
            XCTAssertEqual(reason, "Inappropriate content detected")
        } else {
            XCTFail("Expected contentFiltered error")
        }
    }

    // MARK: - Error Equality Tests

    func testModelNotAvailable_equalsItself() {
        let error1 = LLMError.modelNotAvailable("gpt-4")
        let error2 = LLMError.modelNotAvailable("gpt-4")

        XCTAssertEqual(error1, error2)
    }

    func testModelNotAvailable_doesNotEqualDifferentModel() {
        let error1 = LLMError.modelNotAvailable("gpt-4")
        let error2 = LLMError.modelNotAvailable("claude-3")

        XCTAssertNotEqual(error1, error2)
    }

    func testFrameworkNotAvailable_equalsItself() {
        let error1 = LLMError.frameworkNotAvailable
        let error2 = LLMError.frameworkNotAvailable

        XCTAssertEqual(error1, error2)
    }

    func testInvalidMessageFormat_equalsItself() {
        let error1 = LLMError.invalidMessageFormat("Same message")
        let error2 = LLMError.invalidMessageFormat("Same message")

        XCTAssertEqual(error1, error2)
    }

    func testInvalidMessageFormat_doesNotEqualDifferentMessage() {
        let error1 = LLMError.invalidMessageFormat("Message 1")
        let error2 = LLMError.invalidMessageFormat("Message 2")

        XCTAssertNotEqual(error1, error2)
    }

    func testContentFiltered_equalsItself() {
        let error1 = LLMError.contentFiltered("Same reason")
        let error2 = LLMError.contentFiltered("Same reason")

        XCTAssertEqual(error1, error2)
    }

    func testContentFiltered_doesNotEqualDifferentReason() {
        let error1 = LLMError.contentFiltered("Reason 1")
        let error2 = LLMError.contentFiltered("Reason 2")

        XCTAssertNotEqual(error1, error2)
    }

    func testDifferentErrorTypes_areNotEqual() {
        let error1 = LLMError.modelNotAvailable("gpt-4")
        let error2 = LLMError.frameworkNotAvailable

        XCTAssertNotEqual(error1, error2)
    }

    // MARK: - LocalizedError Protocol Tests

    func testModelNotAvailable_errorDescription() {
        let error = LLMError.modelNotAvailable("gpt-4")

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("gpt-4"))
    }

    func testModelNotAvailable_failureReason() {
        let error = LLMError.modelNotAvailable("gpt-4")

        XCTAssertNotNil(error.failureReason)
        XCTAssertFalse(error.failureReason!.isEmpty)
    }

    func testModelNotAvailable_recoverySuggestion() {
        let error = LLMError.modelNotAvailable("gpt-4")

        XCTAssertNotNil(error.recoverySuggestion)
        XCTAssertFalse(error.recoverySuggestion!.isEmpty)
    }

    func testFrameworkNotAvailable_errorDescription() {
        let error = LLMError.frameworkNotAvailable

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("macOS 26.0"))
    }

    func testFrameworkNotAvailable_failureReason() {
        let error = LLMError.frameworkNotAvailable

        XCTAssertNotNil(error.failureReason)
        XCTAssertTrue(error.failureReason!.contains("macOS 26.0"))
    }

    func testFrameworkNotAvailable_recoverySuggestion() {
        let error = LLMError.frameworkNotAvailable

        XCTAssertNotNil(error.recoverySuggestion)
        XCTAssertTrue(error.recoverySuggestion!.contains("macOS 26.0"))
    }

    func testInvalidMessageFormat_errorDescription() {
        let error = LLMError.invalidMessageFormat("Empty array")

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("Empty array"))
    }

    func testInvalidMessageFormat_failureReason() {
        let error = LLMError.invalidMessageFormat("Empty array")

        XCTAssertNotNil(error.failureReason)
        XCTAssertFalse(error.failureReason!.isEmpty)
    }

    func testInvalidMessageFormat_recoverySuggestion() {
        let error = LLMError.invalidMessageFormat("Empty array")

        XCTAssertNotNil(error.recoverySuggestion)
        XCTAssertFalse(error.recoverySuggestion!.isEmpty)
    }

    func testContentFiltered_errorDescription() {
        let error = LLMError.contentFiltered("Unsafe content")

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("Unsafe content"))
    }

    func testContentFiltered_failureReason() {
        let error = LLMError.contentFiltered("Unsafe content")

        XCTAssertNotNil(error.failureReason)
        XCTAssertFalse(error.failureReason!.isEmpty)
    }

    func testContentFiltered_recoverySuggestion() {
        let error = LLMError.contentFiltered("Unsafe content")

        XCTAssertNotNil(error.recoverySuggestion)
        XCTAssertFalse(error.recoverySuggestion!.isEmpty)
    }
}

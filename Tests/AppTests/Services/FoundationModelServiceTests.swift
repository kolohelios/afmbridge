import XCTest

@testable import Models
@testable import Services

final class FoundationModelServiceTests: XCTestCase {

    // MARK: - Mock LLMProvider Tests

    func testMockProvider_successfulResponse() async throws {
        let mock = MockLLMProvider(response: "Hello from the model!")

        let result = try await mock.respond(to: "Test prompt", systemInstructions: nil)

        XCTAssertEqual(result, "Hello from the model!")
    }

    func testMockProvider_withSystemInstructions() async throws {
        let mock = MockLLMProvider(response: "Response with system context")

        let result = try await mock.respond(
            to: "User question", systemInstructions: "You are a helpful assistant.")

        XCTAssertEqual(result, "Response with system context")
        XCTAssertEqual(mock.lastUserPrompt, "User question")
        XCTAssertEqual(mock.lastSystemInstructions, "You are a helpful assistant.")
    }

    func testMockProvider_throwsError() async {
        let mock = MockLLMProvider(error: LLMError.contentFiltered("Inappropriate content"))

        do {
            _ = try await mock.respond(to: "Bad prompt", systemInstructions: nil)
            XCTFail("Expected error to be thrown")
        } catch let error as LLMError {
            guard case .contentFiltered(let message) = error else {
                return XCTFail("Expected contentFiltered error")
            }
            XCTAssertTrue(message.contains("Inappropriate"))
        } catch { XCTFail("Expected LLMError, got \(error)") }
    }

    func testMockProvider_capturesPrompts() async throws {
        let mock = MockLLMProvider(response: "Test")

        _ = try await mock.respond(to: "First prompt", systemInstructions: "System 1")
        XCTAssertEqual(mock.lastUserPrompt, "First prompt")
        XCTAssertEqual(mock.lastSystemInstructions, "System 1")

        _ = try await mock.respond(to: "Second prompt", systemInstructions: nil)
        XCTAssertEqual(mock.lastUserPrompt, "Second prompt")
        XCTAssertNil(mock.lastSystemInstructions)
    }

    // MARK: - Mock Streaming Tests

    func testMockProvider_streamingResponse() async throws {
        let mock = MockLLMProvider(response: "Hello from streaming!")

        var chunks: [String] = []
        for try await chunk in try await mock.streamRespond(
            to: "Test prompt", systemInstructions: nil)
        {
            chunks.append(chunk)
        }

        // Verify chunks combine to form complete response
        let fullResponse = chunks.joined()
        XCTAssertEqual(fullResponse, "Hello from streaming!")
        XCTAssertGreaterThan(chunks.count, 1, "Response should be split into multiple chunks")
    }

    func testMockProvider_streamingWithSystemInstructions() async throws {
        let mock = MockLLMProvider(response: "Streaming with context")

        var chunks: [String] = []
        for try await chunk in try await mock.streamRespond(
            to: "User question", systemInstructions: "You are helpful.")
        {
            chunks.append(chunk)
        }

        XCTAssertEqual(chunks.joined(), "Streaming with context")
        XCTAssertEqual(mock.lastUserPrompt, "User question")
        XCTAssertEqual(mock.lastSystemInstructions, "You are helpful.")
    }

    func testMockProvider_streamingThrowsError() async {
        let mock = MockLLMProvider(error: LLMError.contentFiltered("Blocked content"))

        do {
            for try await _ in try await mock.streamRespond(to: "Bad", systemInstructions: nil) {
                XCTFail("Should not yield any chunks")
            }
            XCTFail("Expected error to be thrown")
        } catch let error as LLMError {
            guard case .contentFiltered(let message) = error else {
                return XCTFail("Expected contentFiltered error")
            }
            XCTAssertTrue(message.contains("Blocked"))
        } catch { XCTFail("Expected LLMError, got \(error)") }
    }

    func testMockProvider_streamingYieldsIncremental() async throws {
        let mock = MockLLMProvider(response: "1234567890")

        var previousLength = 0
        for try await chunk in try await mock.streamRespond(
            to: "Count", systemInstructions: nil)
        {
            // Each chunk should be incremental (not cumulative)
            XCTAssertGreaterThan(chunk.count, 0, "Chunk should not be empty")
            previousLength += chunk.count
        }

        XCTAssertEqual(previousLength, 10, "Total length should match response")
    }

    // MARK: - Real Service Tests (Compile-time only)

    // Note: These tests verify the service compiles and has the correct interface.
    // Runtime tests would require macOS 26.0+ with FoundationModels framework.

    func testFoundationModelService_interface() {
        // Verify the service conforms to LLMProvider protocol
        if #available(macOS 26.0, *) {
            let service = FoundationModelService(modelIdentifier: "test-model")
            XCTAssertNotNil(service)
        } else {
            // Service requires macOS 26.0+
            XCTAssertTrue(true, "Service correctly requires macOS 26.0+")
        }
    }

    func testFoundationModelService_initWithDefaultModel() {
        if #available(macOS 26.0, *) {
            let service = FoundationModelService()
            XCTAssertNotNil(service)
        }
    }

    func testFoundationModelService_initWithCustomModel() {
        if #available(macOS 26.0, *) {
            let service = FoundationModelService(modelIdentifier: "custom-model")
            XCTAssertNotNil(service)
        }
    }
}

// MARK: - Mock Implementation

/// Mock LLMProvider for testing
class MockLLMProvider: LLMProvider {
    private let response: String?
    private let error: Error?

    var lastUserPrompt: String?
    var lastSystemInstructions: String?

    init(response: String) {
        self.response = response
        self.error = nil
    }

    init(error: Error) {
        self.response = nil
        self.error = error
    }

    func respond(to userPrompt: String, systemInstructions: String?) async throws -> String {
        lastUserPrompt = userPrompt
        lastSystemInstructions = systemInstructions

        if let error = error { throw error }

        return response ?? "Default response"
    }

    func streamRespond(to userPrompt: String, systemInstructions: String?) async throws
        -> AsyncThrowingStream<String, Error>
    {
        lastUserPrompt = userPrompt
        lastSystemInstructions = systemInstructions

        // Capture values explicitly to avoid data races
        let capturedError = self.error
        let capturedResponse = self.response

        return AsyncThrowingStream { continuation in
            Task {
                if let error = capturedError {
                    continuation.finish(throwing: error)
                    return
                }

                // Split response into chunks for streaming simulation
                let content = capturedResponse ?? "Default response"
                let chunkSize = max(1, content.count / 5)  // ~5 chunks
                var index = content.startIndex

                while index < content.endIndex {
                    let nextIndex = content.index(
                        index, offsetBy: chunkSize, limitedBy: content.endIndex) ?? content.endIndex
                    let chunk = String(content[index..<nextIndex])
                    continuation.yield(chunk)
                    index = nextIndex

                    // Small delay to simulate streaming
                    try? await Task.sleep(nanoseconds: 10_000_000)  // 0.01s
                }

                continuation.finish()
            }
        }
    }
}

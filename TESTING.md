# Testing Guide

Comprehensive testing documentation for AFMBridge.

## Test Types

### Unit Tests

Test individual components in isolation:

```bash
swift test
```

Located in `Tests/AppTests/`:

- **DTOs/**: Data transfer object validation
- **Services/**: Business logic and model interaction
- **Controllers/**: HTTP endpoint logic
- **Configuration/**: Environment and config handling

### Integration Tests

Test complete request/response flows:

```bash
swift test --filter Integration
```

Located in `Tests/AppTests/Integration/`:

- **Phase1IntegrationTests**: Non-streaming OpenAI API
- **SDKIntegrationTests**: SDK compatibility (manual/local-only)

### SDK Integration Tests

Verify compatibility with official OpenAI and Anthropic Python SDKs.

**Requirements:**

- macOS 26.0+ with FoundationModels framework
- Python 3.8+ (provided by Nix dev shell)
- AFMBridge server running locally

**Running SDK Tests:**

```bash
# Enter Nix dev shell (includes Python + SDK packages)
nix develop

# Start AFMBridge server
swift run &

# Run OpenAI SDK tests
python3 Tests/SDKTests/test_openai_sdk.py

# Or run via Swift test wrapper (auto-skips if requirements not met)
swift test --filter SDKIntegrationTests
```

**What's Tested:**

- ✅ OpenAI SDK non-streaming chat
- ✅ OpenAI SDK streaming chat (requires Phase 2)
- ⏳ Anthropic SDK (Phase 3+)

See `Tests/SDKTests/README.md` for detailed SDK test documentation.

## Running Tests

### All Tests

```bash
# Run all tests
just test

# Or directly
swift test
```

### Specific Test Suite

```bash
# Run only Phase 1 integration tests
swift test --filter Phase1IntegrationTests

# Run only DTO tests
swift test --filter OpenAITests
```

### With Coverage

```bash
# Run tests with code coverage
swift test --enable-code-coverage

# View coverage report (macOS)
xcrun llvm-cov show \
  .build/debug/afmbridgePackageTests.xctest/Contents/MacOS/afmbridgePackageTests \
  --instr-profile .build/debug/codecov/default.profdata
```

## Test Organization

```text
Tests/
├── AppTests/              # Swift unit and integration tests
│   ├── Configuration/     # Config tests
│   ├── Controllers/       # Controller tests
│   ├── DTOs/              # DTO validation tests
│   ├── Integration/       # End-to-end integration tests
│   └── Services/          # Service layer tests
└── SDKTests/              # Python SDK integration tests
    ├── README.md          # SDK test documentation
    ├── test_openai_sdk.py # OpenAI SDK compatibility
    └── test_anthropic_sdk.py  # Anthropic SDK (Phase 3+)
```

## Coverage Requirements

AFMBridge maintains **80% minimum code coverage**.

Check coverage:

```bash
just test  # Runs tests with coverage enabled
```

## CI Behavior

### GitHub Actions CI

**What runs:**

- ✅ All Swift unit tests
- ✅ Swift integration tests
- ✅ SDK integration tests (with real FoundationModels)

**CI Environment:**

- macOS 26 runners with FoundationModels framework
- Python SDK packages via Nix dev shell
- Real AFM testing (not mocked)

SDK tests run automatically in CI with the same environment as local development.

### Local Development

**Same environment as CI:**

- macOS 26.0+ with FoundationModels
- Nix dev shell (provides Python SDK packages)
- Tests validate real AFM integration

## Writing Tests

### Unit Test Example

```swift
final class MyServiceTests: XCTestCase {
    func testServiceLogic() {
        // Given: Setup test data
        let input = "test"

        // When: Execute logic
        let result = MyService.process(input)

        // Then: Verify expectations
        XCTAssertEqual(result, expected)
    }
}
```

### Integration Test Example

```swift
func testEndpoint() async throws {
    let app = try await makeTestApp()
    defer { Task { try await app.asyncShutdown() } }

    try await app.test(.POST, "v1/endpoint") { res async in
        XCTAssertEqual(res.status, .ok)
    }
}
```

### SDK Test Example

```python
def test_openai_compatibility():
    client = OpenAI(base_url="http://localhost:8080/v1")
    response = client.chat.completions.create(
        model="gpt-4o",
        messages=[{"role": "user", "content": "Hello"}]
    )
    assert response.choices[0].message.content
```

## Troubleshooting

### Tests Fail Locally

1. Check Swift version: `swift --version` (need 6.0+)
2. Clean build: `just clean && just build`
3. Verify dependencies: `swift package resolve`

### SDK Tests Skip

SDK tests auto-skip when:

- macOS < 26.0
- FoundationModels unavailable
- Python openai/anthropic packages not installed

**Note:** CI runs on macOS 26 with all packages, so tests should NOT skip in CI.
If SDK tests skip in CI, that's a failure - investigate the environment.

### Coverage Too Low

1. Run with coverage: `swift test --enable-code-coverage`
2. Identify uncovered code
3. Add tests for uncovered paths
4. Target: 80% minimum coverage

## Further Reading

- [Swift Testing](https://www.swift.org/documentation/swift-testing/)
- [Vapor Testing](https://docs.vapor.codes/testing/overview/)
- [XCTest Documentation](https://developer.apple.com/documentation/xctest)

import Foundation

/// Errors that can occur when interacting with Foundation Models
enum LLMError: LocalizedError { /// The requested model is not available on this system
    case modelNotAvailable(String)

    /// The FoundationModels framework is not available (requires macOS 26.0+)
    case frameworkNotAvailable

    /// The message format provided is invalid or malformed
    case invalidMessageFormat(String)

    /// Content was filtered by safety systems
    case contentFiltered(String)

    var errorDescription: String? {
        switch self {
        case .modelNotAvailable(let model):
            return "Model '\(model)' is not available on this system"
        case .frameworkNotAvailable:
            return "FoundationModels framework is not available (requires macOS 26.0+)"
        case .invalidMessageFormat(let details): return "Invalid message format: \(details)"
        case .contentFiltered(let reason): return "Content was filtered: \(reason)"
        }
    }

    var failureReason: String? {
        switch self {
        case .modelNotAvailable: return "The requested language model is not installed or supported"
        case .frameworkNotAvailable:
            return "This feature requires macOS 26.0 or later with FoundationModels framework"
        case .invalidMessageFormat:
            return "The message structure does not conform to expected format"
        case .contentFiltered: return "Safety filters prevented content generation"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .modelNotAvailable:
            return "Check that the model is available and try again with a supported model"
        case .frameworkNotAvailable: return "Update to macOS 26.0 or later to use this feature"
        case .invalidMessageFormat:
            return "Ensure messages follow the correct structure with valid roles and content"
        case .contentFiltered: return "Modify your request to comply with content safety guidelines"
        }
    }
}

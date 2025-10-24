# Contributing to SwiftCompartido

Thank you for your interest in contributing to SwiftCompartido! This document provides guidelines and instructions for contributing.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Process](#development-process)
- [Coding Standards](#coding-standards)
- [Testing Requirements](#testing-requirements)
- [Pull Request Process](#pull-request-process)
- [Reporting Bugs](#reporting-bugs)
- [Suggesting Enhancements](#suggesting-enhancements)

## Code of Conduct

### Our Pledge

We are committed to providing a welcoming and inclusive environment for all contributors, regardless of age, body size, disability, ethnicity, gender identity and expression, level of experience, nationality, personal appearance, race, religion, or sexual identity and orientation.

### Our Standards

**Examples of behavior that contributes to a positive environment:**

- Using welcoming and inclusive language
- Being respectful of differing viewpoints and experiences
- Gracefully accepting constructive criticism
- Focusing on what is best for the community
- Showing empathy towards other community members

**Examples of unacceptable behavior:**

- The use of sexualized language or imagery
- Trolling, insulting/derogatory comments, and personal or political attacks
- Public or private harassment
- Publishing others' private information without explicit permission
- Other conduct which could reasonably be considered inappropriate in a professional setting

## Getting Started

### Prerequisites

- iOS 26.0+ or Mac Catalyst 26.0+
- Xcode 16.0+
- Swift 6.2+
- Git

### Setting Up Your Development Environment

1. **Fork the repository** on GitHub

2. **Clone your fork**:
   ```bash
   git clone https://github.com/YOUR_USERNAME/SwiftCompartido.git
   cd SwiftCompartido
   ```

3. **Add upstream remote**:
   ```bash
   git remote add upstream https://github.com/intrusive-memory/SwiftCompartido.git
   ```

4. **Build the project**:
   ```bash
   swift build
   ```

5. **Run tests**:
   ```bash
   swift test
   ```

All tests should pass before you start making changes.

## Development Process

### Branching Strategy

We use a simplified Git workflow:

- `main` - Production-ready code
- `feature/*` - New features
- `bugfix/*` - Bug fixes
- `docs/*` - Documentation updates
- `refactor/*` - Code refactoring

### Creating a Feature Branch

```bash
# Update your main branch
git checkout main
git pull upstream main

# Create a feature branch
git checkout -b feature/my-amazing-feature

# Or for a bugfix
git checkout -b bugfix/fix-audio-playback
```

### Making Changes

1. **Write code** following our [coding standards](#coding-standards)
2. **Write tests** for your changes (aim for 90%+ coverage)
3. **Run tests** to ensure everything passes
4. **Update documentation** if needed
5. **Commit your changes** with clear commit messages

### Commit Message Guidelines

We follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types**:
- `feat`: A new feature
- `fix`: A bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

**Examples**:

```
feat(audio): add support for WAV format playback

Added WAV file format support to AudioPlayerManager with
proper MIME type detection and validation.

Closes #123
```

```
fix(parser): handle empty dialogue elements correctly

Fixed crash when parsing Fountain files with empty dialogue
elements. Added validation and comprehensive test coverage.

Fixes #456
```

```
docs(readme): update installation instructions

Updated README with clearer Swift Package Manager installation
steps and added troubleshooting section.
```

## Coding Standards

### Swift Style Guide

We follow the [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/) and [Swift Style Guide](https://google.github.io/swift/).

### Key Principles

1. **Clarity at the point of use** - Names should make code self-documenting
2. **Prefer clear over brief** - `removeAll()` over `clear()`
3. **Use fluent usage** - Functions read like English sentences
4. **Use type inference** - When it improves readability

### Naming Conventions

```swift
// ✅ GOOD
public func generateAudio(from text: String, using voiceID: String) async throws -> GeneratedAudioRecord

// ❌ BAD
public func genAud(txt: String, vid: String) async throws -> GeneratedAudioRecord
```

### Code Organization

```swift
// MARK: - Type Definition
public struct MyModel: Sendable {
    // MARK: - Properties
    public let id: UUID
    public var name: String

    // MARK: - Initialization
    public init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }

    // MARK: - Public Methods
    public func doSomething() {
        // Implementation
    }

    // MARK: - Private Methods
    private func helperMethod() {
        // Implementation
    }
}

// MARK: - Protocol Conformance
extension MyModel: Codable {
    // Codable implementation
}
```

### Documentation

All public APIs must be documented:

```swift
/// Generates audio from text using text-to-speech.
///
/// This method calls the TTS provider, saves the audio to a file,
/// and creates a SwiftData record with a file reference.
///
/// - Parameters:
///   - text: The text to convert to speech
///   - voiceID: The voice identifier for the TTS provider
///   - storage: Storage area for the audio file
/// - Returns: A GeneratedAudioRecord with file reference
/// - Throws: `AIServiceError` if generation fails
///
/// ## Example
/// ```swift
/// let record = try await generateAudio(
///     from: "Hello, world!",
///     using: "rachel-voice",
///     storage: storage
/// )
/// ```
@available(iOS 26.0, macCatalyst 26.0, *)
public func generateAudio(
    from text: String,
    using voiceID: String,
    storage: StorageAreaReference
) async throws -> GeneratedAudioRecord {
    // Implementation
}
```

### Concurrency

All code must be Swift 6 concurrency-safe:

```swift
// ✅ GOOD - Use @MainActor for UI updates
@MainActor
@Observable
class ViewModel {
    var isLoading = false

    func loadData() async {
        isLoading = true
        defer { isLoading = false }

        // Heavy work on background
        let data = await Task.detached {
            // Network/processing
        }.value
    }
}

// ✅ GOOD - All models are Sendable
public struct AIResponseData: Sendable {
    // Properties
}

// ❌ BAD - Mutable global state
var globalCache: [String: Data] = [:] // Not thread-safe!
```

### Error Handling

Always use typed errors and provide recovery suggestions:

```swift
// ✅ GOOD
public enum MyError: Error, LocalizedError {
    case invalidInput(String)
    case networkFailure(underlying: Error)

    public var errorDescription: String? {
        switch self {
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        case .networkFailure:
            return "Network request failed"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .invalidInput:
            return "Check that the input matches the expected format"
        case .networkFailure:
            return "Check your internet connection and try again"
        }
    }
}

// ❌ BAD
enum MyError: Error {
    case error // Too generic
}
```

## Testing Requirements

### Test Coverage

- **Minimum**: 80% code coverage
- **Target**: 90%+ code coverage
- **All public APIs** must have tests

### Testing Framework

We use **Swift Testing** (not XCTest) for all new tests:

```swift
import Testing
@testable import SwiftCompartido

struct MyFeatureTests {

    @Test("Feature does something correctly")
    func testFeature() throws {
        // Arrange
        let sut = MyFeature()

        // Act
        let result = try sut.doSomething()

        // Assert
        #expect(result == expectedValue)
    }

    @Test("Feature throws error on invalid input")
    func testFeatureError() {
        let sut = MyFeature()

        #expect(throws: MyError.self) {
            try sut.doSomethingInvalid()
        }
    }
}
```

### Test Structure

```swift
struct FeatureTests {
    // MARK: - Test Fixtures

    func makeTestData() -> TestData {
        // Setup test data
    }

    // MARK: - Initialization Tests

    @Test("Initializes with default values")
    func testDefaultInitialization() {
        // Test
    }

    // MARK: - Functionality Tests

    @Test("Performs expected operation")
    func testOperation() {
        // Test
    }

    // MARK: - Error Tests

    @Test("Throws error on invalid input")
    func testErrorHandling() {
        // Test
    }

    // MARK: - Integration Tests

    @Test("Complete workflow works end-to-end")
    func testIntegration() {
        // Test
    }
}
```

### Running Tests

```bash
# Run all tests
swift test

# Run specific test suite
swift test --filter MyFeatureTests

# Run with coverage
swift test --enable-code-coverage

# Generate coverage report
xcrun llvm-cov report .build/debug/SwiftCompartidoPackageTests.xctest/Contents/MacOS/SwiftCompartidoPackageTests \
    -instr-profile .build/debug/codecov/default.profdata
```

### Test Best Practices

1. **Test one thing at a time** - Each test should verify a single behavior
2. **Use descriptive names** - Test names should explain what is being tested
3. **Arrange-Act-Assert** - Structure tests clearly
4. **Test edge cases** - Include boundary conditions, empty inputs, etc.
5. **Mock external dependencies** - Don't rely on network/disk in unit tests
6. **Clean up resources** - Use `defer` or test teardown

## Pull Request Process

### Before Submitting

1. ✅ All tests pass (`swift test`)
2. ✅ Code follows style guidelines
3. ✅ Documentation is updated
4. ✅ Commit messages follow convention
5. ✅ No merge conflicts with `main`

### Creating a Pull Request

1. **Push your branch**:
   ```bash
   git push origin feature/my-amazing-feature
   ```

2. **Open a Pull Request** on GitHub

3. **Fill out the PR template**:

```markdown
## Description
Brief description of the changes

## Motivation and Context
Why is this change needed? What problem does it solve?

## Type of Change
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to change)
- [ ] Documentation update

## How Has This Been Tested?
Describe the tests you ran to verify your changes.

## Screenshots (if applicable)
Add screenshots for UI changes

## Checklist
- [ ] My code follows the code style of this project
- [ ] I have added tests to cover my changes
- [ ] All new and existing tests passed
- [ ] I have updated the documentation accordingly
- [ ] My changes generate no new warnings
```

### Review Process

1. **Automated checks** will run (tests, linting)
2. **Maintainers will review** your code
3. **Address feedback** if requested
4. **Approval** - Once approved, your PR will be merged

### After Merge

1. **Delete your branch**:
   ```bash
   git branch -d feature/my-amazing-feature
   git push origin --delete feature/my-amazing-feature
   ```

2. **Update your local main**:
   ```bash
   git checkout main
   git pull upstream main
   ```

## Reporting Bugs

### Before Reporting

1. **Check existing issues** - Your bug may already be reported
2. **Verify it's a bug** - Make sure it's not expected behavior
3. **Test on latest version** - Ensure you're using the latest release

### Bug Report Template

```markdown
**Describe the bug**
A clear and concise description of what the bug is.

**To Reproduce**
Steps to reproduce the behavior:
1. Initialize with '...'
2. Call method '....'
3. See error

**Expected behavior**
A clear description of what you expected to happen.

**Actual behavior**
What actually happened.

**Code Sample**
```swift
// Minimal code to reproduce the issue
let manager = AudioPlayerManager()
try manager.play(from: url, format: "mp3")
// Crashes here
```

**Environment**
- OS: [e.g., iOS 26.0 / Mac Catalyst 26.0]
- Swift Version: [e.g., 6.2]
- SwiftCompartido Version: [e.g., 3.0.0]
- Xcode Version: [e.g., 16.0]

**Additional context**
Add any other context about the problem here.

**Logs/Stack Trace**
```
Paste any relevant logs or stack traces here
```
```

## Suggesting Enhancements

### Enhancement Proposal Template

```markdown
**Is your feature request related to a problem?**
A clear description of what the problem is. Ex. I'm always frustrated when [...]

**Describe the solution you'd like**
A clear description of what you want to happen.

**Describe alternatives you've considered**
A clear description of any alternative solutions or features you've considered.

**Proposed API**
```swift
// How would the API look?
public func newFeature(param: String) async throws -> Result
```

**Use Cases**
Describe real-world scenarios where this would be useful.

**Additional context**
Add any other context or screenshots about the feature request here.
```

## Development Tips

### Debugging

```swift
// Use print statements for quick debugging
print("DEBUG: Value is \(value)")

// Use breakpoints in Xcode
// Set conditional breakpoints for specific scenarios
```

### Performance Testing

```swift
import Foundation

// Measure execution time
let start = Date()
// Code to measure
let duration = Date().timeIntervalSince(start)
print("Duration: \(duration)s")
```

### Memory Profiling

Use Xcode Instruments to profile memory usage, especially for file I/O operations.

## Questions?

If you have questions about contributing, feel free to:

- **Open a discussion**: [GitHub Discussions](https://github.com/intrusive-memory/SwiftCompartido/discussions)
- **Ask in an issue**: [GitHub Issues](https://github.com/intrusive-memory/SwiftCompartido/issues)

## Recognition

Contributors are recognized in:
- GitHub contributors list
- Release notes
- Special thanks section in documentation

Thank you for contributing to SwiftCompartido! 🎉

---

**Last Updated**: 2025-10-19
**Version**: 1.3.0

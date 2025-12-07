# Contributing to PlugInKit

Thank you for your interest in contributing to PlugInKit! This document provides guidelines and instructions for contributing.

## Code of Conduct

Be respectful, professional, and constructive in all interactions.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/PluginKit.git`
3. Create a feature branch: `git checkout -b feature/your-feature-name`
4. Make your changes
5. Test thoroughly
6. Commit and push
7. Create a Pull Request

## Development Setup

### Requirements

- macOS 10.15 or later
- Xcode 12 or later
- Swift 5.0+ (if using Swift)

### Building

```bash
# Using Swift Package Manager
swift build

# Using Xcode
open PlugInKit.xcodeproj
```

## Coding Standards

### Objective-C

- Follow Apple's Objective-C coding guidelines
- Use modern Objective-C features (nullability annotations, generics, etc.)
- Document public APIs with HeaderDoc comments
- Use two-space indentation
- Maximum line length: 120 characters

Example:
```objective-c
/// Processes data with the specified options
/// @param data Input data to process
/// @param options Processing options
/// @param completion Completion handler called with result
- (void)processData:(NSString *)data
        withOptions:(NSDictionary<NSString *, id> *)options
         completion:(void (^)(NSString * _Nullable result, NSError * _Nullable error))completion;
```

### Swift

- Follow Swift API Design Guidelines
- Use Swift naming conventions
- Document public APIs with Swift documentation comments
- Use four-space indentation
- Maximum line length: 120 characters

Example:
```swift
/// Processes data with the specified options
/// - Parameters:
///   - data: Input data to process
///   - options: Processing options
///   - completion: Completion handler called with result
func processData(_ data: String,
                options: [String: Any],
                completion: @escaping (String?, Error?) -> Void)
```

## Architecture Guidelines

### Modern API Design

Follow Network.framework-inspired patterns:

1. **State Management**: Use explicit state enums
2. **Completion Handlers**: Use completion blocks for async operations
3. **Delegate Patterns**: Use delegates for event notification
4. **Queue-Based**: Use dispatch queues for thread safety
5. **Error Handling**: Use NSError with proper domains and codes

### XPC Communication

- All plugin communication must go through XPC
- Use secure coding for all transferred objects
- Handle connection interruptions and invalidations gracefully
- Implement proper error recovery

### Thread Safety

- Use serial queues for state management
- Document thread safety guarantees
- Avoid blocking the main queue
- Use dispatch barriers for write operations

## Testing

### Unit Tests

- Write tests for all new functionality
- Maintain or improve code coverage
- Use XCTest framework
- Mock XPC connections where appropriate

### Integration Tests

- Test plugin discovery and connection
- Test bidirectional communication
- Test error handling and recovery
- Test connection health monitoring

## Documentation

### Code Documentation

- Document all public APIs
- Use HeaderDoc (Objective-C) or Swift documentation comments
- Include usage examples for complex APIs
- Document thread safety and completion queue guarantees

### README Updates

- Update README.md for new features
- Add examples for new functionality
- Update requirements if changed

## Pull Request Process

1. **Description**: Clearly describe what your PR does
2. **Testing**: Describe how you tested your changes
3. **Breaking Changes**: Highlight any breaking changes
4. **Documentation**: Update documentation as needed
5. **Code Review**: Address reviewer feedback promptly

### PR Checklist

- [ ] Code follows style guidelines
- [ ] All tests pass
- [ ] New functionality has tests
- [ ] Documentation is updated
- [ ] No compiler warnings
- [ ] Commit messages are clear and descriptive

## Commit Messages

Use clear, descriptive commit messages:

```
Add connection health monitoring

- Implement automatic polling with configurable interval
- Add health states: healthy, degraded, unhealthy
- Track latency metrics over time
- Add delegate callbacks for health changes
```

### Format

- First line: Brief summary (50 chars or less)
- Blank line
- Detailed description (wrap at 72 chars)
- Reference issues: "Fixes #123"

## Feature Requests

Open an issue with:
- Clear description of the feature
- Use cases and benefits
- Proposed API (if applicable)
- Willingness to implement

## Bug Reports

Open an issue with:
- Clear description of the bug
- Steps to reproduce
- Expected vs actual behavior
- System information (macOS version, Xcode version)
- Sample code if possible

## Code Review Guidelines

### For Authors

- Keep PRs focused and reasonably sized
- Respond to feedback promptly
- Be open to suggestions
- Test thoroughly before submitting

### For Reviewers

- Be constructive and respectful
- Focus on code quality and correctness
- Consider architecture and maintainability
- Approve when satisfied, request changes when needed

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

## Questions?

- Open an issue for general questions
- Check existing issues and documentation first
- Be specific and provide context

Thank you for contributing to PlugInKit!

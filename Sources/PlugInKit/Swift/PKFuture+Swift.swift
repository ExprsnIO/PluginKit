//
//  PKFuture+Swift.swift
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

import Foundation

// MARK: - Swift Extensions for PKFuture

@available(macOS 10.15, *)
extension PKFuture {

    /// Create a future from async/await
    @available(macOS 12.0, *)
    public static func from<T>(_ operation: @escaping () async throws -> T) -> PKFuture {
        PKFuture { fulfill, reject in
            Task {
                do {
                    let result = try await operation()
                    fulfill(result as Any)
                } catch {
                    reject(error as NSError)
                }
            }
        }
    }

    /// Convert future to async/await
    @available(macOS 12.0, *)
    public func async<T>() async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            self.onComplete { value, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let typedValue = value as? T {
                    continuation.resume(returning: typedValue)
                } else if T.self == Void.self {
                    continuation.resume(returning: () as! T)
                } else {
                    let error = NSError(domain: PKFutureErrorDomain,
                                      code: Int(PKFutureError.invalidState.rawValue),
                                      userInfo: [NSLocalizedDescriptionKey: "Type mismatch"])
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Await the future value
    @available(macOS 12.0, *)
    public func await<T>() async throws -> T {
        try await async()
    }
}

// MARK: - Swift-Friendly Builders

@available(macOS 10.15, *)
extension PKFuture {

    /// Create a future with Swift closure syntax
    public static func promise<T>(_ resolver: @escaping (@escaping (Result<T, Error>) -> Void) -> Void) -> PKFuture {
        PKFuture { fulfill, reject in
            resolver { result in
                switch result {
                case .success(let value):
                    fulfill(value as Any)
                case .failure(let error):
                    reject(error as NSError)
                }
            }
        }
    }

    /// Create a fulfilled future with type safety
    public static func resolved<T>(_ value: T) -> PKFuture {
        PKFuture.fulfilled(withValue: value as Any)
    }

    /// Create a rejected future with error
    public static func failed(_ error: Error) -> PKFuture {
        PKFuture.rejected(withError: error as NSError)
    }
}

// MARK: - Combine Integration

#if canImport(Combine)
import Combine

@available(macOS 10.15, *)
extension PKFuture {

    /// Convert future to Combine publisher
    public var publisher: AnyPublisher<Any, Error> {
        Future<Any, Error> { promise in
            self.onComplete { value, error in
                if let error = error {
                    promise(.failure(error))
                } else {
                    promise(.success(value ?? NSNull()))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    /// Create future from Combine publisher
    public static func from<P: Publisher>(_ publisher: P) -> PKFuture where P.Failure == Error {
        var cancellable: AnyCancellable?

        return PKFuture { fulfill, reject in
            cancellable = publisher.sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        reject(error as NSError)
                    }
                },
                receiveValue: { value in
                    fulfill(value as Any)
                }
            )
        }
    }
}
#endif

// MARK: - Swift Operators

@available(macOS 10.15, *)
extension PKFuture {

    /// Pipe operator for chaining
    public static func |> (lhs: PKFuture, rhs: @escaping (Any?) -> Any?) -> PKFuture {
        lhs.then(rhs)
    }

    /// Bind operator for flatMap
    public static func >>- (lhs: PKFuture, rhs: @escaping (Any?) -> PKFuture?) -> PKFuture {
        lhs.flatMap(rhs)
    }
}

// MARK: - Collection Extensions

@available(macOS 10.15, *)
extension Array where Element == PKFuture {

    /// Wait for all futures to complete
    public var allFutures: PKFuture {
        PKFuture.all(self)
    }

    /// Race all futures
    public var raceFutures: PKFuture {
        PKFuture.race(self)
    }

    /// Get first successfully completed future
    public var anyFuture: PKFuture {
        PKFuture.any(self)
    }
}

// MARK: - Typed Future Wrapper

/// Type-safe wrapper around PKFuture
@available(macOS 10.15, *)
public struct Future<T> {
    private let wrapped: PKFuture

    public init(_ resolver: @escaping (@escaping (T) -> Void, @escaping (Error) -> Void) -> Void) {
        self.wrapped = PKFuture { fulfill, reject in
            resolver(
                { value in fulfill(value as Any) },
                { error in reject(error as NSError) }
            )
        }
    }

    public init(wrapping future: PKFuture) {
        self.wrapped = future
    }

    public static func resolved(_ value: T) -> Future<T> {
        Future(wrapping: PKFuture.fulfilled(withValue: value as Any))
    }

    public static func rejected(_ error: Error) -> Future<T> {
        Future(wrapping: PKFuture.rejected(withError: error as NSError))
    }

    /// Map the future's value
    public func map<U>(_ transform: @escaping (T) -> U) -> Future<U> {
        Future<U>(wrapping: wrapped.map { value in
            guard let typed = value as? T else { return nil }
            return transform(typed) as Any
        })
    }

    /// Flat map the future's value
    public func flatMap<U>(_ transform: @escaping (T) -> Future<U>) -> Future<U> {
        Future<U>(wrapping: wrapped.flatMap { value in
            guard let typed = value as? T else { return nil }
            return transform(typed).wrapped
        })
    }

    /// Filter the future's value
    public func filter(_ predicate: @escaping (T) -> Bool) -> Future<T> {
        Future<T>(wrapping: wrapped.filter { value in
            guard let typed = value as? T else { return false }
            return predicate(typed)
        })
    }

    /// Recover from error
    public func recover(_ recovery: @escaping (Error) -> T) -> Future<T> {
        Future<T>(wrapping: wrapped.catch { error in
            recovery(error) as Any
        })
    }

    /// Execute on success
    public func onSuccess(_ action: @escaping (T) -> Void) -> Future<T> {
        wrapped.onSuccess { value in
            if let typed = value as? T {
                action(typed)
            }
        }
        return self
    }

    /// Execute on failure
    public func onFailure(_ action: @escaping (Error) -> Void) -> Future<T> {
        wrapped.onFailure(action)
        return self
    }

    /// Convert to untyped PKFuture
    public var pkFuture: PKFuture {
        wrapped
    }

    /// Wait for completion
    public func wait() throws -> T {
        var error: NSError?
        let value = wrapped.wait(withTimeout: 0, error: &error)

        if let error = error {
            throw error
        }

        guard let typed = value as? T else {
            throw NSError(domain: PKFutureErrorDomain,
                        code: Int(PKFutureError.invalidState.rawValue),
                        userInfo: [NSLocalizedDescriptionKey: "Type mismatch"])
        }

        return typed
    }

    /// Convert to async/await
    @available(macOS 12.0, *)
    public func async() async throws -> T {
        try await wrapped.async()
    }
}

// MARK: - Async/Await Helpers

@available(macOS 12.0, *)
extension PKFuture {

    /// Run multiple futures concurrently
    public static func concurrent<T>(_ operations: [() async throws -> T]) async throws -> [T] {
        try await withThrowingTaskGroup(of: T.self) { group in
            for operation in operations {
                group.addTask {
                    try await operation()
                }
            }

            var results: [T] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }
    }

    /// Retry with async/await
    public static func retry<T>(
        maxAttempts: Int,
        delay: TimeInterval = 1.0,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?

        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                if attempt < maxAttempts {
                    let backoff = delay * pow(2.0, Double(attempt - 1))
                    try await Task.sleep(nanoseconds: UInt64(backoff * 1_000_000_000))
                }
            }
        }

        throw lastError ?? NSError(domain: PKFutureErrorDomain,
                                  code: Int(PKFutureError.invalidState.rawValue),
                                  userInfo: [NSLocalizedDescriptionKey: "All retry attempts failed"])
    }

    /// Execute with timeout using async/await
    public static func withTimeout<T>(
        _ timeout: TimeInterval,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw NSError(domain: PKFutureErrorDomain,
                            code: Int(PKFutureError.timeout.rawValue),
                            userInfo: [NSLocalizedDescriptionKey: "Operation timed out"])
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}

// MARK: - Result Builders

@available(macOS 10.15, *)
@resultBuilder
public struct FutureBuilder {
    public static func buildBlock(_ futures: PKFuture...) -> [PKFuture] {
        futures
    }

    public static func buildArray(_ futures: [PKFuture]) -> [PKFuture] {
        futures
    }

    public static func buildOptional(_ future: PKFuture?) -> [PKFuture] {
        future.map { [$0] } ?? []
    }

    public static func buildEither(first: PKFuture) -> PKFuture {
        first
    }

    public static func buildEither(second: PKFuture) -> PKFuture {
        second
    }
}

@available(macOS 10.15, *)
extension PKFuture {

    /// Execute futures using result builder
    public static func execute(@FutureBuilder _ builder: () -> [PKFuture]) -> PKFuture {
        PKFuture.all(builder())
    }
}

//
//  SwiftFuturesExample.swift
//  PlugInKit Swift Futures Example
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

import Foundation
import PlugInKit

@available(macOS 10.15, *)
class SwiftFuturesExample {

    // MARK: - Basic Futures

    func demonstrateBasicFutures() {
        print("\n=== Basic Futures (Swift) ===\n")

        // 1. Create a future
        let simple = PKFuture { fulfill, reject in
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                fulfill("Hello from Swift!")
            }
        }

        simple.onSuccess { value in
            print("Simple future: \(value ?? "nil")")
        }

        // 2. Type-safe future
        let typed = Future<String> { fulfill, reject in
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) {
                fulfill("Type-safe value")
            }
        }

        typed.onSuccess { value in
            print("Typed future: \(value)")
        }

        // 3. Promise-style
        let promise = PKFuture.promise<Int> { resolve in
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
                resolve(.success(42))
            }
        }

        promise.onSuccess { value in
            print("Promise result: \(value ?? "nil")")
        }
    }

    // MARK: - Chaining

    func demonstrateChaining() {
        print("\n=== Chaining (Swift) ===\n")

        let chain = PKFuture.fulfilled(withValue: 10 as Any)

        chain
            .then { value in
                print("Step 1: \(value ?? "nil")")
                return ((value as? Int) ?? 0) * 2 as Any
            }
            .then { value in
                print("Step 2: \(value ?? "nil")")
                return ((value as? Int) ?? 0) + 5 as Any
            }
            .then { value in
                print("Step 3: \(value ?? "nil")")
                return "Result: \(value ?? "nil")" as Any
            }
            .onSuccess { value in
                print("Final: \(value ?? "nil")")
            }

        // Type-safe chaining
        Future.resolved(10)
            .map { $0 * 2 }
            .map { $0 + 5 }
            .map { "Result: \($0)" }
            .onSuccess { value in
                print("Type-safe chain: \(value)")
            }
    }

    // MARK: - Error Handling

    func demonstrateErrorHandling() {
        print("\n=== Error Handling (Swift) ===\n")

        let error = NSError(domain: "example", code: 500)
        let failing = PKFuture.rejected(withError: error)

        failing
            .catch { err in
                print("Caught error: \(err), recovering...")
                return "Recovered" as Any
            }
            .onSuccess { value in
                print("After recovery: \(value ?? "nil")")
            }

        // Type-safe recovery
        Future<String>.rejected(error)
            .recover { err in
                print("Type-safe recovery from: \(err)")
                return "Default value"
            }
            .onSuccess { value in
                print("Recovered: \(value)")
            }
    }

    // MARK: - Composition

    func demonstrateComposition() {
        print("\n=== Composition (Swift) ===\n")

        let futures = [
            PKFuture.after(0.3, value: "First"),
            PKFuture.after(0.2, value: "Second"),
            PKFuture.after(0.1, value: "Third")
        ]

        // All
        futures.allFutures.onSuccess { results in
            print("All completed: \(results ?? [])")
        }

        // Race
        futures.raceFutures.onSuccess { winner in
            print("Race winner: \(winner ?? "nil")")
        }

        // Any (first successful)
        futures.anyFuture.onSuccess { first in
            print("Any succeeded: \(first ?? "nil")")
        }
    }

    // MARK: - Operators

    func demonstrateOperators() {
        print("\n=== Operators (Swift) ===\n")

        let future = PKFuture.fulfilled(withValue: 5 as Any)

        // Pipe operator
        let piped = future |> { value in
            ((value as? Int) ?? 0) * 2 as Any
        } |> { value in
            "Piped: \(value ?? "nil")" as Any
        }

        piped.onSuccess { value in
            print("Pipe result: \(value ?? "nil")")
        }

        // Bind operator
        let bound = future >>- { value in
            PKFuture.fulfilled(withValue: ((value as? Int) ?? 0) + 10 as Any)
        } >>- { value in
            PKFuture.fulfilled(withValue: "Bound: \(value ?? "nil")" as Any)
        }

        bound.onSuccess { value in
            print("Bind result: \(value ?? "nil")")
        }
    }

    // MARK: - While Loops

    func demonstrateWhileLoop() {
        print("\n=== While Loops (Swift) ===\n")

        var counter = 0

        PKFuture.while({ value in
            counter < 5
        }, do: { value in
            let current = counter
            counter += 1
            print("While iteration \(current)")
            return PKFuture.after(0.1, value: current as Any)
        }, initial: 0 as Any)
        .onSuccess { value in
            print("While loop completed: \(value ?? "nil")")
        }
    }

    // MARK: - Repeat and ForEach

    func demonstrateIterations() {
        print("\n=== Iterations (Swift) ===\n")

        // Repeat
        PKFuture.repeat(3) { iteration in
            print("Repeat iteration \(iteration)")
            return PKFuture.after(0.1, value: iteration as Any)
        }
        .onSuccess { value in
            print("Repeat completed: \(value ?? "nil")")
        }

        // ForEach
        PKFuture.forEach(["Apple", "Banana", "Cherry"]) { item, index in
            print("Processing \(index): \(item)")
            return PKFuture.after(0.1, value: (item as! String).uppercased() as Any)
        }
        .onSuccess { results in
            print("ForEach results: \(results ?? [])")
        }
    }

    // MARK: - Async/Await

    @available(macOS 12.0, *)
    func demonstrateAsyncAwait() async {
        print("\n=== Async/Await (Swift) ===\n")

        do {
            // Create future from async
            let future = PKFuture.from {
                try await Task.sleep(nanoseconds: 100_000_000)
                return "Async result"
            }

            let result: String = try await future.async()
            print("Async/await result: \(result)")

            // Type-safe async
            let typed = Future<Int> { fulfill, _ in
                Task {
                    try await Task.sleep(nanoseconds: 100_000_000)
                    fulfill(42)
                }
            }

            let typedResult = try await typed.async()
            print("Type-safe async result: \(typedResult)")

            // Concurrent execution
            let concurrent = try await PKFuture.concurrent([
                { "Task 1" },
                { "Task 2" },
                { "Task 3" }
            ])
            print("Concurrent results: \(concurrent)")

            // Retry
            var attempts = 0
            let retried = try await PKFuture.retry(maxAttempts: 3) {
                attempts += 1
                print("Async retry attempt \(attempts)")
                if attempts < 3 {
                    throw NSError(domain: "retry", code: 1)
                }
                return "Success on attempt \(attempts)"
            }
            print("Retry result: \(retried)")

            // With timeout
            let timedOut = try await PKFuture.withTimeout(1.0) {
                try await Task.sleep(nanoseconds: 100_000_000)
                return "Completed in time"
            }
            print("Timeout result: \(timedOut)")

        } catch {
            print("Async/await error: \(error)")
        }
    }

    // MARK: - Plugin Integration

    func demonstratePluginIntegration() {
        print("\n=== Plugin Integration (Swift) ===\n")

        let manager = PKPlugInManager.shared()

        manager.discoverPlugIns { plugIns, error in
            guard let info = plugIns.first else {
                print("No plugins found for demonstration")
                return
            }

            // Create future from async operation
            let connectFuture = PKFuture.fromAsync { completion in
                manager.connectToPlugIn(info.identifier, configuration: [:]) { connection, error in
                    completion(connection, error)
                }
            }

            // Chain operations
            connectFuture
                .thenFuture { connection -> PKFuture? in
                    guard let conn = connection as? PKConnection else { return nil }
                    print("Connected to \(conn.plugInIdentifier)")
                    return conn.getCapabilities()
                }
                .then { capabilities in
                    print("Capabilities: \(capabilities ?? [:])")
                    return capabilities
                }
                .catch { error in
                    print("Error: \(error)")
                    return ["error": error.localizedDescription] as Any
                }
                .finally {
                    print("Pipeline completed")
                }
        }
    }

    // MARK: - Result Builder

    @available(macOS 10.15, *)
    func demonstrateResultBuilder() {
        print("\n=== Result Builder (Swift) ===\n")

        let pipeline = PKFuture.execute {
            PKFuture.after(0.1, value: "Step 1")
            PKFuture.after(0.1, value: "Step 2")
            PKFuture.after(0.1, value: "Step 3")
        }

        pipeline.onSuccess { results in
            print("Result builder pipeline: \(results ?? [])")
        }
    }

    // MARK: - Combine Integration

    #if canImport(Combine)
    @available(macOS 10.15, *)
    func demonstrateCombine() {
        print("\n=== Combine Integration (Swift) ===\n")

        import Combine

        var cancellables = Set<AnyCancellable>()

        // Future to Publisher
        let future = PKFuture.fulfilled(withValue: "Combine value")

        future.publisher
            .sink(
                receiveCompletion: { completion in
                    print("Publisher completed: \(completion)")
                },
                receiveValue: { value in
                    print("Publisher value: \(value)")
                }
            )
            .store(in: &cancellables)

        // Publisher to Future
        let publisher = Just("From publisher")
            .setFailureType(to: Error.self)

        let fromPublisher = PKFuture.from(publisher)

        fromPublisher.onSuccess { value in
            print("Future from publisher: \(value ?? "nil")")
        }
    }
    #endif

    // MARK: - Run All

    func runAllExamples() {
        print("\n╔════════════════════════════════════════╗")
        print("║  PlugInKit Swift Futures Examples     ║")
        print("╚════════════════════════════════════════╝\n")

        demonstrateBasicFutures()
        demonstrateChaining()
        demonstrateErrorHandling()
        demonstrateComposition()
        demonstrateOperators()
        demonstrateWhileLoop()
        demonstrateIterations()
        demonstratePluginIntegration()
        demonstrateResultBuilder()

        #if canImport(Combine)
        if #available(macOS 10.15, *) {
            demonstrateCombine()
        }
        #endif

        if #available(macOS 12.0, *) {
            Task {
                await demonstrateAsyncAwait()

                // Wait for async operations
                try await Task.sleep(nanoseconds: 6_000_000_000)
                print("\n=== All Examples Complete ===\n")
                exit(0)
            }
        } else {
            // Wait for async operations
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                print("\n=== All Examples Complete ===\n")
                exit(0)
            }
        }
    }
}

// MARK: - Main

@available(macOS 10.15, *)
@main
struct Main {
    static func main() {
        let example = SwiftFuturesExample()
        example.runAllExamples()
        RunLoop.main.run()
    }
}

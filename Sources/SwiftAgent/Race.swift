//
//  Race.swift
//  SwiftAgent
//
//  Created by Norikazu Muramoto on 2025/01/25.
//


import Foundation

/// A step that executes multiple steps concurrently and returns the first successful result.
///
/// `Race` allows you to run multiple steps in parallel and get the result from whichever
/// step completes first successfully. If all steps fail, it combines their errors.
///
/// Example:
/// ```swift
/// struct FastestResponder: Agent {
///     var body: some Step<Query, Response> {
///         Race {
///             SlowButReliableAPI()
///             FastButFlakyAPI()
///             LocalCache()
///         }
///     }
/// }
/// ```
public struct Race<Input: Sendable, Output: Sendable>: Step {
    
    public typealias T = Step<Input, Output> & Sendable
    
    private let steps: [any T]
    
    public init(@ParallelStepBuilder builder: () -> [any T]) {
        self.steps = builder()
    }
    
    public init(
        timeout: Duration,
        @ParallelStepBuilder builder: () -> [any T]
    ) {
        let timeoutStep = TimeoutStep(timeout: timeout)
        self.steps = [timeoutStep] + builder()
    }
    
    public func run(_ input: Input) async throws -> Output {
        try await withThrowingTaskGroup(of: Output.self) { group in
            for step in steps {
                group.addTask { @Sendable in
                    try await step.run(input)
                }
            }
            
            do {
                guard let result = try await group.next() else {
                    throw RaceError.noSuccessfulResults
                }
                group.cancelAll()
                return result
            } catch {
                group.cancelAll()
                throw error
            }
        }
    }
}

/// Errors that can occur during race execution.
public enum RaceError: Error {
    /// No steps completed successfully.
    case noSuccessfulResults
}


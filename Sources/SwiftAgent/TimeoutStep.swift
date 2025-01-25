//
//  TimeoutStep.swift
//  SwiftAgent
//
//  Created by Norikazu Muramoto on 2025/01/25.
//


/// A step that fails after a timeout period.
public struct TimeoutStep: Step, Sendable {
    
    let timeout: Duration
    
    public init(timeout: Duration) {
        self.timeout = timeout
    }
    
    public func run(_ input: Void) async throws -> Never {
        try await Task.sleep(for: timeout)
        throw RaceError.noSuccessfulResults
    }
}

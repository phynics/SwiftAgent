//
//  Monitor.swift
//  SwiftAgent
//
//  Created by Norikazu Muramoto on 2025/01/13.
//



/// A step that monitors input and output of a wrapped step
public struct Monitor<S: Step>: Step {
    public typealias Input = S.Input
    public typealias Output = S.Output
    
    private let step: S
    private let onInput: ((Input) async -> Void)?
    private let onOutput: ((Output) async -> Void)?
    
    internal init(
        step: S,
        onInput: ((Input) async -> Void)? = nil,
        onOutput: ((Output) async -> Void)? = nil
    ) {
        self.step = step
        self.onInput = onInput
        self.onOutput = onOutput
    }
    
    public func run(_ input: Input) async throws -> Output {
        // Monitor input
        await onInput?(input)
        
        // Run the wrapped step
        let output = try await step.run(input)
        
        // Monitor output
        await onOutput?(output)
        
        return output
    }
}

// Extension for modifier-style usage
extension Step {
    /// Adds a monitor for the input of this step
    /// - Parameter handler: A closure that receives the input
    /// - Returns: A Monitor wrapping this step
    public func onInput(_ handler: @escaping (Input) async -> Void) -> Monitor<Self> {
        Monitor(step: self, onInput: handler)
    }
    
    /// Adds a monitor for the output of this step
    /// - Parameter handler: A closure that receives the output
    /// - Returns: A Monitor wrapping this step
    public func onOutput(_ handler: @escaping (Output) async -> Void) -> Monitor<Self> {
        Monitor(step: self, onOutput: handler)
    }
    
    /// Adds monitors for both input and output of this step
    /// - Parameters:
    ///   - inputHandler: A closure that receives the input
    ///   - outputHandler: A closure that receives the output
    /// - Returns: A Monitor wrapping this step
    public func monitor(
        input inputHandler: @escaping (Input) async -> Void,
        output outputHandler: @escaping (Output) async -> Void
    ) -> Monitor<Self> {
        Monitor(step: self, onInput: inputHandler, onOutput: outputHandler)
    }
}

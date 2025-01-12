//
//  Print.swift
//  SwiftAgent
//
//  Created by Norikazu Muramoto on 2025/01/13.
//


/// A step that prints the input and output of a wrapped step
public struct Print<S: Step>: Step {
    public typealias Input = S.Input
    public typealias Output = S.Output
    
    private let step: S
    private let prefix: String
    private let inputTransform: ((Input) -> String)?
    private let outputTransform: ((Output) -> String)?
    
    /// Initializes a new Print step
    /// - Parameters:
    ///   - prefix: An optional string to prefix printed messages
    ///   - step: The step to wrap
    ///   - inputTransform: An optional closure to transform input before printing
    ///   - outputTransform: An optional closure to transform output before printing
    public init(
        _ prefix: String = "",
        step: S,
        inputTransform: ((Input) -> String)? = nil,
        outputTransform: ((Output) -> String)? = nil
    ) {
        self.prefix = prefix
        self.step = step
        self.inputTransform = inputTransform
        self.outputTransform = outputTransform
    }
    
    public func run(_ input: Input) async throws -> Output {
        // Print input
        if let transform = inputTransform {
            print("\(prefix)Input: \(transform(input))")
        } else {
            print("\(prefix)Input: \(String(describing: input))")
        }
        
        // Run the wrapped step
        let output = try await step.run(input)
        
        // Print output
        if let transform = outputTransform {
            print("\(prefix)Output: \(transform(output))")
        } else {
            print("\(prefix)Output: \(String(describing: output))")
        }
        
        return output
    }
}

// Extension for easier usage
extension Step {
    /// Wraps this step in a Print step
    /// - Parameters:
    ///   - prefix: A string to prefix printed messages
    ///   - inputTransform: An optional closure to transform input before printing
    ///   - outputTransform: An optional closure to transform output before printing
    /// - Returns: A Print step wrapping this step
    public func log(
        _ prefix: String = "",
        inputTransform: ((Input) -> String)? = nil,
        outputTransform: ((Output) -> String)? = nil
    ) -> Print<Self> {
        Print(prefix, step: self, inputTransform: inputTransform, outputTransform: outputTransform)
    }
}

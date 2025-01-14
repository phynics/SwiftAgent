//
//  Agent.swift
//  SwiftAgent
//
//  Created by Norikazu Muramoto on 2025/01/12.
//

import Foundation
@_exported import JSONSchema

/// A protocol representing a single step in a process.
///
/// `Step` takes an input of a specific type and produces an output of another type asynchronously.
///
/// - Note: The input and output types must conform to both `Codable` and `Sendable` to ensure
///   compatibility with serialization and concurrency.
public protocol Step<Input, Output> {
    
    /// The type of input required by the step.
    associatedtype Input: Sendable
    
    /// The type of output produced by the step.
    associatedtype Output: Sendable
    
    /// Executes the step with the given input and produces an output asynchronously.
    ///
    /// - Parameter input: The input for the step.
    /// - Returns: The output produced by the step.
    /// - Throws: An error if the step fails to execute or the input is invalid.
    func run(_ input: Input) async throws -> Output
}

/// A protocol that defines a tool with input, output, and functionality.
///
/// `Tool` provides a standardized interface for tools that operate on specific input types
/// to produce specific output types asynchronously.
public protocol Tool: Identifiable, Step where Input: Codable, Output: Codable & CustomStringConvertible {
    
    /// A unique name identifying the tool.
    ///
    /// - Note: The `name` should be unique across all tools to avoid conflicts.
    var name: String { get }
    
    /// A description of what the tool does.
    ///
    /// - Note: Use this property to provide detailed information about the tool's purpose and functionality.
    var description: String { get }
    
    /// The JSON schema defining the structure of the tool's input and output.
    ///
    /// - Note: This schema ensures the tool's input and output adhere to a predefined format.
    var parameters: JSONSchema { get }
    
    /// Detailed guide providing comprehensive information about how to use the tool.
    ///
    /// - Note:
    ///   The `guide` should include the following sections:
    ///
    ///   1. **Tool Name**:
    ///      - The unique name of the tool.
    ///      - This name should be descriptive and clearly indicate the tool's purpose.
    ///
    ///   2. **Description**:
    ///      - A concise explanation of the tool's purpose and functionality.
    ///      - This section should help users understand what the tool does at a high level.
    ///
    ///   3. **Parameters**:
    ///      - A list of all input parameters required or optional for using the tool.
    ///      - For each parameter:
    ///        - **Name**: The parameter name.
    ///        - **Type**: The data type (e.g., `String`, `Int`).
    ///        - **Description**: A short description of the parameter's role.
    ///        - **Requirements**: Any constraints, such as valid ranges or allowed values.
    ///
    ///   4. **Usage**:
    ///      - Instructions or guidelines for using the tool effectively.
    ///      - This section should include any constraints, best practices, and common pitfalls.
    ///      - For example, explain how to handle invalid inputs or edge cases.
    ///
    ///   5. **Examples**:
    ///      - Provide practical examples demonstrating how to use the tool in real scenarios.
    ///      - Examples should include valid inputs and expected outputs, formatted as code snippets.
    ///
    ///   Here is an example of what the `guide` might look like:
    ///   ```markdown
    ///   # Tool Name
    ///   ExampleTool
    ///
    ///   ## Description
    ///   This tool calculates the length of a string.
    ///
    ///   ## Parameters
    ///   - `input`: The string whose length will be calculated.
    ///     - **Type**: `String`
    ///     - **Description**: The input text to process.
    ///     - **Requirements**: Must not be empty or null.
    ///
    ///   ## Usage
    ///   - Input strings must be UTF-8 encoded.
    ///   - Ensure the string contains at least one character.
    ///   - Avoid using strings containing unsupported characters.
    ///
    ///   ## Examples
    ///   ### Basic Usage
    ///   ```xml
    ///   <example_tool>
    ///   <input>Hello, world!</input>
    ///   </example_tool>
    ///   ```
    ///
    ///   ### Edge Case
    ///   ```xml
    ///   <example_tool>
    ///   <input> </input> <!-- Invalid: whitespace-only string -->
    ///   </example_tool>
    ///   ```
    ///   ```
    var guide: String? { get }
}

extension Tool {
    
    public var id: String { name }
    
    public func call(_ arguments: any Encodable) async throws -> String {
        let jsonData = try JSONEncoder().encode(arguments)
        let args: Self.Input = try JSONDecoder().decode(
            Input.self,
            from: jsonData
        )
        do {
            let result = try await run(args)

            return "\(result)"
        } catch {
            return "[\(name)] has Error: \(error)"
        }
    }
    
    public func call(data: Data) async throws -> String {
        let args: Self.Input = try JSONDecoder().decode(
            Input.self,
            from: data
        )
        do {
            let result = try await run(args)
            return "\(result)"
        } catch {
            return "[\(name)] has Error: \(error)"
        }
    }
}

/// Errors that can occur during tool execution.
public enum ToolError: Error {
    
    /// Required parameters are missing.
    case missingParameters([String])
    
    /// Parameters are invalid.
    case invalidParameters(String)
    
    /// Tool execution failed.
    case executionFailed(String)
    
    /// A localized description of the error.
    public var localizedDescription: String {
        switch self {
        case .missingParameters(let params):
            return "Missing required parameters: \(params.joined(separator: ", "))"
        case .invalidParameters(let message):
            return "Invalid parameters: \(message)"
        case .executionFailed(let message):
            return "Execution failed: \(message)"
        }
    }
}

/// A protocol representing a language model (LLM), which extends the `Step` protocol.
///
/// `Model` defines a system prompt and can utilize a set of tools to assist in its operations.
public protocol Model: Step {
    
    /// The system prompt used by the model.
    ///
    /// - Note: This prompt serves as the base context for the model's behavior.
    var systemPrompt: String { get }
    
    /// A collection of tools available to the model for assisting in its operations.
    ///
    /// - Note: Tools can be used by the model to perform specialized tasks.
    var tools: [any Tool] { get }
}

/// A protocol representing an agent, which acts as a composite step by combining multiple steps.
///
/// `Agent` is composed of a body that defines its behavior and operates as a higher-level abstraction
/// over individual steps.
///
/// - Note: The `Input` and `Output` types of the `Agent` match those of its `Body`.
public protocol Agent: Step where Input == Body.Input, Output == Body.Output {
    
    /// The type of the body, which must conform to `Step`.
    associatedtype Body: Step
    
    /// A builder property that defines the body of the agent.
    ///
    /// - Note: The body determines how the agent processes its input and generates its output.
    @StepBuilder var body: Self.Body { get }
}

extension Agent {
    
    /// Executes the agent's operation by delegating to its body.
    ///
    /// - Parameter input: The input for the agent.
    /// - Returns: The output produced by the agent's body.
    /// - Throws: An error if the agent's body fails to execute.
    public func run(_ input: Input) async throws -> Output {
        try await body.run(input)
    }
}


/// A step that does nothing and simply passes the input as the output.
public struct EmptyStep<Input: Sendable>: Step {
    public typealias Output = Input
    
    @inlinable public init() {}
    
    public func run(_ input: Input) async throws -> Output {
        input
    }
}

/// A result builder to combine steps into chains.
@resultBuilder
public struct StepBuilder {
    
    public static func buildBlock<Content>(_ content: Content) -> Content where Content: Step {
        content
    }
    
    public static func buildBlock<S1: Step, S2: Step>(_ step1: S1, _ step2: S2) -> Chain2<S1, S2> where S1.Output == S2.Input {
        Chain2(step1, step2)
    }
    
    public static func buildBlock<S1: Step, S2: Step, S3: Step>(_ step1: S1, _ step2: S2, _ step3: S3) -> Chain3<S1, S2, S3> where S1.Output == S2.Input, S2.Output == S3.Input {
        Chain3(step1, step2, step3)
    }
    
    public static func buildBlock<S1: Step, S2: Step, S3: Step, S4: Step>(_ step1: S1, _ step2: S2, _ step3: S3, _ step4: S4) -> Chain4<S1, S2, S3, S4> where S1.Output == S2.Input, S2.Output == S3.Input, S3.Output == S4.Input {
        Chain4(step1, step2, step3, step4)
    }
    
    public static func buildBlock<S1: Step, S2: Step, S3: Step, S4: Step, S5: Step>(_ step1: S1, _ step2: S2, _ step3: S3, _ step4: S4, _ step5: S5) -> Chain5<S1, S2, S3, S4, S5> where S1.Output == S2.Input, S2.Output == S3.Input, S3.Output == S4.Input, S4.Output == S5.Input {
        Chain5(step1, step2, step3, step4, step5)
    }
    
    public static func buildBlock<S1: Step, S2: Step, S3: Step, S4: Step, S5: Step, S6: Step>(_ step1: S1, _ step2: S2, _ step3: S3, _ step4: S4, _ step5: S5, _ step6: S6) -> Chain6<S1, S2, S3, S4, S5, S6> where S1.Output == S2.Input, S2.Output == S3.Input, S3.Output == S4.Input, S4.Output == S5.Input, S5.Output == S6.Input {
        Chain6(step1, step2, step3, step4, step5, step6)
    }
    
    public static func buildBlock<S1: Step, S2: Step, S3: Step, S4: Step, S5: Step, S6: Step, S7: Step>(_ step1: S1, _ step2: S2, _ step3: S3, _ step4: S4, _ step5: S5, _ step6: S6, _ step7: S7) -> Chain7<S1, S2, S3, S4, S5, S6, S7> where S1.Output == S2.Input, S2.Output == S3.Input, S3.Output == S4.Input, S4.Output == S5.Input, S5.Output == S6.Input, S6.Output == S7.Input {
        Chain7(step1, step2, step3, step4, step5, step6, step7)
    }
    
    public static func buildBlock<S1: Step, S2: Step, S3: Step, S4: Step, S5: Step, S6: Step, S7: Step, S8: Step>(_ step1: S1, _ step2: S2, _ step3: S3, _ step4: S4, _ step5: S5, _ step6: S6, _ step7: S7, _ step8: S8) -> Chain8<S1, S2, S3, S4, S5, S6, S7, S8> where S1.Output == S2.Input, S2.Output == S3.Input, S3.Output == S4.Input, S4.Output == S5.Input, S5.Output == S6.Input, S6.Output == S7.Input, S7.Output == S8.Input {
        Chain8(step1, step2, step3, step4, step5, step6, step7, step8)
    }
}
/// A structure that combines two `Step` instances and executes them sequentially.
public struct Chain2<S1: Step, S2: Step>: Step where S1.Output == S2.Input {
    public typealias Input = S1.Input
    public typealias Output = S2.Output
    
    public let step1: S1
    public let step2: S2
    
    @inlinable public init(_ step1: S1, _ step2: S2) {
        self.step1 = step1
        self.step2 = step2
    }
    
    public func run(_ input: Input) async throws -> Output {
        let intermediate = try await step1.run(input)
        return try await step2.run(intermediate)
    }
}

/// A structure that combines three `Step` instances and executes them sequentially.
public struct Chain3<S1: Step, S2: Step, S3: Step>: Step where S1.Output == S2.Input, S2.Output == S3.Input {
    public typealias Input = S1.Input
    public typealias Output = S3.Output
    
    public let step1: S1
    public let step2: S2
    public let step3: S3
    
    @inlinable public init(_ step1: S1, _ step2: S2, _ step3: S3) {
        self.step1 = step1
        self.step2 = step2
        self.step3 = step3
    }
    
    public func run(_ input: Input) async throws -> Output {
        let intermediate1 = try await step1.run(input)
        let intermediate2 = try await step2.run(intermediate1)
        return try await step3.run(intermediate2)
    }
}

/// A structure that combines four `Step` instances and executes them sequentially.
public struct Chain4<S1: Step, S2: Step, S3: Step, S4: Step>: Step where S1.Output == S2.Input, S2.Output == S3.Input, S3.Output == S4.Input {
    public typealias Input = S1.Input
    public typealias Output = S4.Output
    
    public let step1: S1
    public let step2: S2
    public let step3: S3
    public let step4: S4
    
    @inlinable public init(_ step1: S1, _ step2: S2, _ step3: S3, _ step4: S4) {
        self.step1 = step1
        self.step2 = step2
        self.step3 = step3
        self.step4 = step4
    }
    
    public func run(_ input: Input) async throws -> Output {
        let intermediate1 = try await step1.run(input)
        let intermediate2 = try await step2.run(intermediate1)
        let intermediate3 = try await step3.run(intermediate2)
        return try await step4.run(intermediate3)
    }
}

public struct Chain5<S1: Step, S2: Step, S3: Step, S4: Step, S5: Step>: Step where S1.Output == S2.Input, S2.Output == S3.Input, S3.Output == S4.Input, S4.Output == S5.Input {
    public typealias Input = S1.Input
    public typealias Output = S5.Output
    
    public let step1: S1
    public let step2: S2
    public let step3: S3
    public let step4: S4
    public let step5: S5
    
    @inlinable public init(_ step1: S1, _ step2: S2, _ step3: S3, _ step4: S4, _ step5: S5) {
        self.step1 = step1
        self.step2 = step2
        self.step3 = step3
        self.step4 = step4
        self.step5 = step5
    }
    
    public func run(_ input: Input) async throws -> Output {
        let intermediate1 = try await step1.run(input)
        let intermediate2 = try await step2.run(intermediate1)
        let intermediate3 = try await step3.run(intermediate2)
        let intermediate4 = try await step4.run(intermediate3)
        return try await step5.run(intermediate4)
    }
}

// 同様に Chain6, Chain7, Chain8 を以下のように実装します：
public struct Chain6<S1: Step, S2: Step, S3: Step, S4: Step, S5: Step, S6: Step>: Step where S1.Output == S2.Input, S2.Output == S3.Input, S3.Output == S4.Input, S4.Output == S5.Input, S5.Output == S6.Input {
    public typealias Input = S1.Input
    public typealias Output = S6.Output
    
    public let step1: S1
    public let step2: S2
    public let step3: S3
    public let step4: S4
    public let step5: S5
    public let step6: S6
    
    @inlinable public init(_ step1: S1, _ step2: S2, _ step3: S3, _ step4: S4, _ step5: S5, _ step6: S6) {
        self.step1 = step1
        self.step2 = step2
        self.step3 = step3
        self.step4 = step4
        self.step5 = step5
        self.step6 = step6
    }
    
    public func run(_ input: Input) async throws -> Output {
        let intermediate1 = try await step1.run(input)
        let intermediate2 = try await step2.run(intermediate1)
        let intermediate3 = try await step3.run(intermediate2)
        let intermediate4 = try await step4.run(intermediate3)
        let intermediate5 = try await step5.run(intermediate4)
        return try await step6.run(intermediate5)
    }
}

public struct Chain7<S1: Step, S2: Step, S3: Step, S4: Step, S5: Step, S6: Step, S7: Step>: Step where S1.Output == S2.Input, S2.Output == S3.Input, S3.Output == S4.Input, S4.Output == S5.Input, S5.Output == S6.Input, S6.Output == S7.Input {
    public typealias Input = S1.Input
    public typealias Output = S7.Output
    
    public let step1: S1
    public let step2: S2
    public let step3: S3
    public let step4: S4
    public let step5: S5
    public let step6: S6
    public let step7: S7
    
    @inlinable public init(_ step1: S1, _ step2: S2, _ step3: S3, _ step4: S4, _ step5: S5, _ step6: S6, _ step7: S7) {
        self.step1 = step1
        self.step2 = step2
        self.step3 = step3
        self.step4 = step4
        self.step5 = step5
        self.step6 = step6
        self.step7 = step7
    }
    
    public func run(_ input: Input) async throws -> Output {
        let intermediate1 = try await step1.run(input)
        let intermediate2 = try await step2.run(intermediate1)
        let intermediate3 = try await step3.run(intermediate2)
        let intermediate4 = try await step4.run(intermediate3)
        let intermediate5 = try await step5.run(intermediate4)
        let intermediate6 = try await step6.run(intermediate5)
        return try await step7.run(intermediate6)
    }
}

public struct Chain8<S1: Step, S2: Step, S3: Step, S4: Step, S5: Step, S6: Step, S7: Step, S8: Step>: Step where S1.Output == S2.Input, S2.Output == S3.Input, S3.Output == S4.Input, S4.Output == S5.Input, S5.Output == S6.Input, S6.Output == S7.Input, S7.Output == S8.Input {
    public typealias Input = S1.Input
    public typealias Output = S8.Output
    
    public let step1: S1
    public let step2: S2
    public let step3: S3
    public let step4: S4
    public let step5: S5
    public let step6: S6
    public let step7: S7
    public let step8: S8
    
    @inlinable public init(_ step1: S1, _ step2: S2, _ step3: S3, _ step4: S4, _ step5: S5, _ step6: S6, _ step7: S7, _ step8: S8) {
        self.step1 = step1
        self.step2 = step2
        self.step3 = step3
        self.step4 = step4
        self.step5 = step5
        self.step6 = step6
        self.step7 = step7
        self.step8 = step8
    }
    
    public func run(_ input: Input) async throws -> Output {
        let intermediate1 = try await step1.run(input)
        let intermediate2 = try await step2.run(intermediate1)
        let intermediate3 = try await step3.run(intermediate2)
        let intermediate4 = try await step4.run(intermediate3)
        let intermediate5 = try await step5.run(intermediate4)
        let intermediate6 = try await step6.run(intermediate5)
        let intermediate7 = try await step7.run(intermediate6)
        return try await step8.run(intermediate7)
    }
}

extension StepBuilder {
    
    public static func buildIf<Content>(_ content: Content?) -> OptionalStep<Content> where Content: Step {
        OptionalStep(content)
    }
    
    public static func buildEither<TrueContent: Step, FalseContent: Step>(
        first: TrueContent
    ) -> ConditionalStep<TrueContent, FalseContent> {
        ConditionalStep(condition: true, first: first, second: nil)
    }
    
    public static func buildEither<TrueContent: Step, FalseContent: Step>(
        second: FalseContent
    ) -> ConditionalStep<TrueContent, FalseContent> {
        ConditionalStep(condition: false, first: nil, second: second)
    }
}

public struct OptionalStep<S: Step>: Step {
    public typealias Input = S.Input
    public typealias Output = S.Output
    
    private let step: S?
    
    public init(_ step: S?) {
        self.step = step
    }
    
    public func run(_ input: Input) async throws -> Output {
        guard let step = step else {
            throw OptionalStepError.stepIsNil
        }
        return try await step.run(input)
    }
}

public enum OptionalStepError: Error {
    case stepIsNil
}

public struct ConditionalStep<TrueStep: Step, FalseStep: Step>: Step where TrueStep.Input == FalseStep.Input, TrueStep.Output == FalseStep.Output {
    public typealias Input = TrueStep.Input
    public typealias Output = TrueStep.Output
    
    private let condition: Bool
    private let first: TrueStep?
    private let second: FalseStep?
    
    public init(condition: Bool, first: TrueStep?, second: FalseStep?) {
        self.condition = condition
        self.first = first
        self.second = second
    }
    
    public func run(_ input: Input) async throws -> Output {
        if condition, let first = first {
            return try await first.run(input)
        } else if let second = second {
            return try await second.run(input)
        }
        throw ConditionalStepError.noStepAvailable
    }
}

public enum ConditionalStepError: Error {
    case noStepAvailable
}

public struct Loop<S: Step>: Step where S.Input == S.Output {
    public typealias Input = S.Input
    public typealias Output = S.Output
    
    private let maxIterations: Int
    private let step: (Input) -> S
    private let condition: (Output) async throws -> Bool
    
    public init(
        max: Int,
        @StepBuilder step:  @escaping (Input) -> S,
        until condition: @escaping (Output) async throws -> Bool
    ) {
        self.maxIterations = max
        self.step = step
        self.condition = condition
    }
    
    public func run(_ input: Input) async throws -> Output {
        var current = input
        for _ in 0..<maxIterations {
            let output = try await step(input).run(current)
            if try await condition(output) {
                return output
            }
            current = output
        }
        throw LoopError.conditionNotMet
    }
}

public enum LoopError: Error {
    case conditionNotMet
}

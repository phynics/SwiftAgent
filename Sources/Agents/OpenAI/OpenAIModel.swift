//
//  OpenAIModel.swift
//  SwiftAgent
//
//  Created by Norikazu Muramoto on 2025/01/13.
//

import Foundation
import SwiftAgent
import AgentTools
@preconcurrency import OpenAI

/// A concrete implementation of the Model protocol using OpenAI's API.
///
/// `OpenAIModel` provides integration with OpenAI's language models through a consistent interface,
/// supporting message handling, tool execution, and response processing.
///
/// Example usage:
/// ```swift
/// let tools = [SearchTool(), CalculatorTool()]
/// let model = OpenAIModel(
///     model: Model.gpt4_o_mini,
///     tools: tools,
///     systemPrompt: { tools in
///         "You are a helpful assistant with these tools: \(tools.map(\.name).joined(separator: ", "))"
///     }
/// )
///
/// let response = try await model.run(messages)
/// ```
public struct OpenAIModel: SwiftAgent.Model {
    
    /// The identifier for the OpenAI model to use.
    public var model: String
    
    /// An array of tools available to the model for executing various tasks.
    public var tools: [any Tool]
    
    /// The system prompt that provides initial context and instructions to the model.
    public var systemPrompt: String
    
    /// The OpenAI client instance for making API calls.
    private let openAI: OpenAI
    
    /// Creates a new instance of OpenAIModel.
    ///
    /// - Parameters:
    ///   - model: The OpenAI model identifier to use. Defaults to GPT-4 Mini.
    ///   - tools: An array of tools that the model can use during execution.
    ///   - systemPrompt: A closure that generates the system prompt based on available tools.
    /// - Throws: Fatal error if OPENAI_API_KEY environment variable is not set.
    public init(
        model: String = Model.gpt4_o_mini,
        tools: [any Tool],
        systemPrompt: ([any Tool]) -> String
    ) {
        guard let apiKey: String = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] else {
            fatalError("OpenAI API Key is not set in environment variables.")
        }
        self.model = model
        self.tools = tools
        self.systemPrompt = systemPrompt(tools)
        self.openAI = OpenAI(apiToken: apiKey)
    }
    
    /// Executes the model with the provided input messages.
    ///
    /// This method:
    /// - Converts tools to OpenAI's format
    /// - Sends the request to OpenAI's API
    /// - Processes tool calls if present
    /// - Handles the response
    ///
    /// - Parameter input: An array of chat messages to process
    /// - Returns: The model's response as a string
    /// - Throws: Errors from OpenAI API or tool execution
    public func run(_ input: [ChatQuery.ChatCompletionMessageParam]) async throws -> String {
        let openAITools = tools.map { tool -> ChatQuery.ChatCompletionToolParam in
                .init(function: .init(
                    name: tool.name,
                    description: tool.description,
                    parameters: try? JSONDecoder().decode(
                        ChatQuery.ChatCompletionToolParam.FunctionDefinition.FunctionParameters.self,
                        from: JSONEncoder().encode(tool.parameters)
                    )
                ))
        }
        
        let messages: [ChatQuery.ChatCompletionMessageParam] = [
            .system(.init(content: systemPrompt))
        ] + input
        
        let query = ChatQuery(
            messages: messages,
            model: model,
            tools: openAITools
        )
        
        let response = try await withCheckedThrowingContinuation { continuation in
            openAI.chats(query: query) { result in
                continuation.resume(with: result)
            }
        }
        
        // Process the response outside the continuation
        if let content = response.choices.first?.message.content?.string {
            return content
        }
        
        if let toolCalls = response.choices.first?.message.toolCalls {
            var output = ""
            for toolCall in toolCalls {
                let function = toolCall.function
                let arguments = function.arguments
                if let tool = tools.first(where: { $0.name == function.name }) {
                    let result = try await tool.call(data: arguments.data(using: .utf8)!)
                    output += "Tool result: \(result)\n"
                }
            }
            return output
        }
        
        return "No content or tool calls received"
    }
}

/// A step that stores assistant messages in the conversation history.
///
/// This step maintains the assistant's responses in OpenAI's message format
/// for context preservation across interactions.
public struct OpenAIMessageStore: Step {
    
    /// The relay property for maintaining message history.
    @Relay var messages: [ChatQuery.ChatCompletionMessageParam]
    
    /// Adds an assistant message to the conversation history.
    ///
    /// - Parameter input: The message content to store
    /// - Returns: The original input message
    public func run(_ input: String) async throws -> String {
        messages.append(.assistant(.init(content: input)))
        return input
    }
}

/// A step that transforms user input into OpenAI's message format.
///
/// This step handles the conversion of user messages into the format
/// expected by OpenAI's API while maintaining conversation history.
public struct OpenAIMessageTransform: Step {
    
    /// The relay property for maintaining message history.
    @Relay var messages: [ChatQuery.ChatCompletionMessageParam]
    
    /// Transforms and stores a user message.
    ///
    /// - Parameter input: The user's message to transform
    /// - Returns: The complete message history including the new message
    public func run(_ input: String) async throws -> [ChatQuery.ChatCompletionMessageParam] {
        messages.append(.user(.init(content: .string(input))))
        return messages
    }
}

/// Retroactive Sendable conformance for ChatResult
extension ChatResult: @retroactive @unchecked Sendable {}

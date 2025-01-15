//
//  OllamaModel.swift
//  SwiftAgent
//
//  Created by Norikazu Muramoto on 2025/01/11.
//

import Foundation
import SwiftAgent
import AgentTools
import OllamaKit

/// A concrete implementation of the `Model` protocol using OllamaKit.
///
/// `OllamaModel` provides integration with Ollama's language models through a consistent interface,
/// supporting streaming responses, tool execution, and message management.
///
/// Example usage:
/// ```swift
/// let tools = [SearchTool(), CalculatorTool()]
/// let model = OllamaModel(
///     model: "llama2",
///     tools: tools,
///     systemPrompt: { tools in
///         "You are a helpful assistant with these tools: \(tools.map(\.name).joined(separator: ", "))"
///     }
/// )
///
/// let response = try await model.run(messages)
/// ```
public struct OllamaModel: Model {
    
    /// The input type for the model, consisting of an array of Ollama chat messages.
    public typealias Input = [OKChatRequestData.Message]
    
    /// The output type for the model, represented as a String response.
    public typealias Output = String
    
    /// The name of the Ollama model to use (e.g., "llama2").
    public var model: String
    
    /// An array of tools available to the model for executing various tasks.
    public var tools: [any Tool]
    
    /// The system prompt that provides initial context and instructions to the model.
    public var systemPrompt: String
    
    /// Creates a new instance of OllamaModel.
    ///
    /// - Parameters:
    ///   - model: The name of the Ollama model to use (e.g., "llama2")
    ///   - tools: An array of tools that the model can use during execution
    ///   - systemPrompt: A closure that generates the system prompt based on available tools
    public init(
        model: String = "llama3.2:latest",
        tools: [any Tool] = [],
        systemPrompt: ([any Tool]) -> String
    ) {
        self.model = model
        self.tools = tools
        self.systemPrompt = systemPrompt(tools)
    }
    
    /// Executes the model with the provided input messages.
    ///
    /// This method:
    /// - Converts tools to Ollama's format
    /// - Handles streaming responses
    /// - Processes tool calls
    /// - Aggregates results
    ///
    /// - Parameter input: An array of chat messages to process
    /// - Returns: The complete response from the model as a string
    /// - Throws: Errors from Ollama API or tool execution
    public func run(_ input: [OKChatRequestData.Message]) async throws -> String {
        let okTools: [OKTool] = tools.map { tool -> OKTool in
                .function(
                    OKFunction(
                        name: tool.name,
                        description: tool.description,
                        parameters: tool.parameters
                    )
                )
        }
        
        let messages: [OKChatRequestData.Message] = [.system(systemPrompt)] + input
        let ollama = OllamaKit()
        let stream: AsyncThrowingStream<OKChatResponse, Error> = ollama.chat(
            data: .init(
                model: model,
                messages: messages,
                tools: okTools
            )
        )
        
        var output = ""
        var toolResults: [String] = []
        
        for try await response in stream {
            if let message = response.message {
                // Add content to output
                output += message.content
                
                // Handle tool calls
                if let toolCalls = message.toolCalls {
                    for toolCall in toolCalls {
                        if let result = try await processToolCall(toolCall) {
                            toolResults.append(result)
                        }
                    }
                }
            }
            
            if response.done {
                break
            }
        }
        
        // If there were tool results, append them to the output
        if !toolResults.isEmpty {
            output += "\n\nTool Results:\n" + toolResults.joined(separator: "\n")
        }
        
        return output
    }
    
    /// Processes a tool call from the model.
    ///
    /// - Parameter toolCall: The tool call request from the model
    /// - Returns: The result of the tool execution as a string, or nil if processing fails
    /// - Throws: Errors from tool execution
    private func processToolCall(_ toolCall: OKChatResponse.Message.ToolCall) async throws -> String? {
        guard let function = toolCall.function,
              let name = function.name,
              let arguments = function.arguments,
              let tool = tools.first(where: { $0.name == name }) else {
            return nil
        }
        return try await tool.call(arguments)
    }
}

/// A step that stores assistant messages in the conversation history.
///
/// This step is responsible for maintaining the assistant's messages in the
/// conversation context.
///
/// Example usage:
/// ```swift
/// let store = OllamaMessageStore()
/// let result = try await store.run("Hello, how can I help?")
/// ```
public struct OllamaMessageStore: Step {
    /// The relay property for maintaining message history
    @Relay var messages: [OKChatRequestData.Message]
    
    /// Adds an assistant message to the conversation history.
    ///
    /// - Parameter input: The message content to store
    /// - Returns: The original input message
    public func run(_ input: String) async throws -> String {
        messages.append(.assistant(input))
        return input
    }
}

/// A step that transforms and stores user messages in the conversation history.
///
/// This step handles the addition of user messages to the conversation context
/// and prepares them for model processing.
///
/// Example usage:
/// ```swift
/// let transform = OllamaMessageTransform()
/// let messages = try await transform.run("What's the weather?")
/// ```
public struct OllamaMessageTransform: Step {
    /// The relay property for maintaining message history
    @Relay var messages: [OKChatRequestData.Message]
    
    /// Transforms and stores a user message.
    ///
    /// - Parameter input: The user's message to store
    /// - Returns: The complete message history including the new message
    public func run(_ input: String) async throws -> [OKChatRequestData.Message] {
        messages.append(.user(input))
        return messages
    }
}

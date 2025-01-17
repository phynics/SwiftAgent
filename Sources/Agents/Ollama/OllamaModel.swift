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

/// A concrete implementation of the Model protocol using OllamaKit.
public struct OllamaModel<Output: Sendable>: Model {
    public typealias Input = [OKChatRequestData.Message]
    
    /// The name of the Ollama model to use
    public let model: String
    
    /// An array of tools available to the model
    public let tools: [any Tool]
    
    /// The system prompt that provides initial context
    public let systemPrompt: String
    
    /// Options for chat completion
    private let format: JSONSchema?
    private let options: OKCompletionOptions?
    
    /// Response parser for converting response to Output type
    private let responseParser: (String) throws -> Output
    
    /// Creates a new instance of OllamaModel for text output
    public init(
        model: String = "llama3.2:latest",
        options: OKCompletionOptions? = nil,
        tools: [any Tool] = [],
        systemPrompt: ([any Tool]) -> String
    ) where Output == String {
        self.model = model
        self.tools = tools
        self.systemPrompt = systemPrompt(tools)
        self.format = nil
        self.options = options
        self.responseParser = { $0 }
    }
    
    /// Creates a new instance of OllamaModel with a Codable output type
    public init(
        model: String = "llama3.2:latest",
        options: OKCompletionOptions? = nil,
        schema: JSONSchema,
        tools: [any Tool] = [],
        systemPrompt: ([any Tool]) -> String
    ) where Output: Codable {
        self.model = model
        self.tools = tools
        self.systemPrompt = systemPrompt(tools)
        self.format = schema
        self.options = options
        self.responseParser = { jsonString in
            guard let data = jsonString.data(using: .utf8) else {
                throw OllamaModelError.invalidResponse
            }
            return try JSONDecoder().decode(Output.self, from: data)
        }
    }
    
    public func run(_ input: Input) async throws -> Output {
        let okTools: [OKTool] = tools.map { tool in
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
        
        let requestData = OKChatRequestData(
            model: model,
            messages: messages,
            tools: okTools.isEmpty ? nil : okTools,
            format: format,
            options: options
        )
        
        let stream: AsyncThrowingStream<OKChatResponse, Error> = ollama.chat(data: requestData)
        
        var output = ""
        var toolResults: [String] = []
        
        for try await response in stream {
            if let message = response.message {
                // Add content to output
                output += message.content
                
                // Handle tool calls
                if let toolCalls = message.toolCalls {
                    for toolCall in toolCalls {
                        print("!!", toolCalls)
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
        
        return try responseParser(output)
    }
    
    private func processToolCall(_ toolCall: OKChatResponse.Message.ToolCall) async throws -> String? {
        guard let function = toolCall.function,
              let name = function.name,
              let arguments = function.arguments,
              let tool = tools.first(where: { $0.name == name }) else {
            return nil
        }
        print("-----", arguments)
        return try await tool.call(arguments)
    }
}

/// Errors specific to OllamaModel
public enum OllamaModelError: Error {
    case invalidResponse
    case noContent
    case modelRefused(String)
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

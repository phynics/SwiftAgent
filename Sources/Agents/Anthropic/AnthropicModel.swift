//
//  AnthropicModel.swift
//  SwiftAgent
//
//  Created by Norikazu Muramoto on 2025/01/13.
//

import Foundation
import SwiftAgent
import AgentTools
@preconcurrency import SwiftAnthropic

/// A concrete implementation of the Model protocol using SwiftAnthropic's API.
///
/// `AnthropicModel` provides a way to interact with Anthropic's language models through a consistent interface.
/// It handles message streaming, tool execution, and response processing.
///
/// Example usage:
/// ```swift
/// let tools = [SearchTool(), CalculatorTool()]
/// let model = AnthropicModel(
///     model: .claude35Haiku,
///     tools: tools,
///     systemPrompt: { tools in
///         "You are a helpful assistant with access to these tools: \(tools.map(\.name).joined(separator: ", "))"
///     }
/// )
///
/// let response = try await model.run(messages)
/// ```
public struct AnthropicModel<Output: Sendable>: SwiftAgent.Model {
    
    /// The input type for the model, consisting of an array of messages.
    public typealias Input = [MessageParameter.Message]
    
    // The underlying Anthropic service client
    private let service: AnthropicService
    
    /// The specific Anthropic model to use
    public var model: SwiftAnthropic.Model
    
    /// An array of tools available to the model
    public var tools: [any Tool]
    
    /// The system prompt that provides initial context
    public var systemPrompt: String
    
    /// Response parser for converting response to Output type
    private let responseParser: (String) throws -> Output
    
    /// Creates a new instance of AnthropicModel for text output
    public init(
        model: SwiftAnthropic.Model = .claude35Haiku,
        tools: [any Tool] = [],
        systemPrompt: ([any Tool]) -> String
    ) where Output == String {
        guard let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] else {
            fatalError("Anthropic API Key is not set in environment variables.")
        }
        
        self.model = model
        self.tools = tools
        self.systemPrompt = systemPrompt(tools)
        self.service = AnthropicServiceFactory.service(apiKey: apiKey, betaHeaders: nil)
        self.responseParser = { $0 }
    }
    
    /// Creates a new instance of AnthropicModel with a Codable output type
    public init(
        model: SwiftAnthropic.Model = .claude35Haiku,
        schema: JSONSchema, // Note: Currently not used by Anthropic, but kept for interface consistency
        tools: [any Tool] = [],
        systemPrompt: ([any Tool]) -> String
    ) where Output: Codable {
        guard let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] else {
            fatalError("Anthropic API Key is not set in environment variables.")
        }
        
        self.model = model
        self.tools = tools
        self.systemPrompt = systemPrompt(tools)
        self.service = AnthropicServiceFactory.service(apiKey: apiKey, betaHeaders: nil)
        
        // Setup the JSON response parser
        self.responseParser = { jsonString in
            guard let data = jsonString.data(using: .utf8) else {
                throw AnthropicModelError.invalidResponse
            }
            // Note: Currently, Anthropic doesn't support direct JSON schema output
            // We attempt to parse the response as JSON, but it may fail
            return try JSONDecoder().decode(Output.self, from: data)
        }
    }
    
    public func run(_ input: [MessageParameter.Message]) async throws -> Output {
        // Convert tools to Anthropic format
        let anthropicTools = tools.map { tool in
            MessageParameter.Tool(
                name: tool.name,
                description: tool.description,
                inputSchema: try? JSONSchema.from(tool.parameters),
                cacheControl: nil
            )
        }
        
        // Build request parameters
        let parameters = MessageParameter(
            model: model,
            messages: input,
            maxTokens: 4096,
            system: .text(systemPrompt),
            stream: false,
            tools: anthropicTools.isEmpty ? nil : anthropicTools
        )
        
        let response = try await service.createMessage(parameters)
        var completeResponse = ""
        
        // Process response content
        for content in response.content {
            switch content {
            case .text(let text, _):
                completeResponse += text
                
            case .toolUse(let toolUse):
                if let result = try await executeToolCall(toolUse) {
                    completeResponse += "\nTool result: \(result)"
                }
                
            case .thinking(let thinking):
                // thinkingの処理を追加
                completeResponse += "\nThinking: \(thinking.thinking)"
            }
        }
        return try responseParser(completeResponse)
    }
    
    private func executeToolCall(_ toolUse: MessageResponse.Content.ToolUse) async throws -> String? {
        guard let tool = tools.first(where: { $0.name == toolUse.name }) else {
            throw AnthropicModelError.toolNotFound(toolUse.name)
        }
        let inputString = try JSONEncoder().encode(toolUse.input)
        return try await tool.call(data: inputString)
    }
}

/// Errors specific to AnthropicModel
public enum AnthropicModelError: Error {
    case invalidResponse
    case noContent
    case toolNotFound(String)
    case jsonParsingFailed
}

/// Errors that can occur during model execution.
public enum ModelError: LocalizedError {
    /// Indicates that a requested tool was not found in the available tools list.
    case toolNotFound(String)
    
    public var errorDescription: String? {
        switch self {
        case .toolNotFound(let name):
            return "Tool not found: \(name)"
        }
    }
}

// MARK: - JSON Schema Extension

extension JSONSchema {
    /// Converts a JSONSchema instance to Anthropic's expected schema format.
    ///
    /// - Parameter schema: The source JSONSchema to convert
    /// - Returns: A converted schema in Anthropic's format
    /// - Throws: Errors if schema conversion fails
    static func from(_ schema: JSONSchema) throws -> MessageParameter.Tool.JSONSchema {
        let type = convertJSONType(schema.type)
        let description = schema.description
        
        var properties: [String: MessageParameter.Tool.JSONSchema.Property] = [:]
        if case .object = schema.type {
            let property = MessageParameter.Tool.JSONSchema.Property(
                type: type,
                description: description
            )
            properties["value"] = property
        }
        
        return MessageParameter.Tool.JSONSchema(
            type: type,
            properties: properties,
            required: []
        )
    }
    
    /// Converts internal schema types to Anthropic's schema types.
    private static func convertJSONType(_ type: SchemaType) -> MessageParameter.Tool.JSONSchema.JSONType {
        switch type {
        case .string:
            return .string
        case .number:
            return .number
        case .integer:
            return .integer
        case .boolean:
            return .boolean
        case .array:
            return .array
        case .object:
            return .object
        case .null, .enum:
            return .string // Handle null and enum as strings
        }
    }
    
    /// Creates a basic property definition for the schema.
    private static func convertToBasicProperty(
        type: MessageParameter.Tool.JSONSchema.JSONType,
        description: String?
    ) -> MessageParameter.Tool.JSONSchema.Property {
        return MessageParameter.Tool.JSONSchema.Property(
            type: type,
            description: description
        )
    }
}

/// A step that stores messages in the Anthropic message history.
///
/// This step is responsible for adding user messages to the conversation history.
struct AnthropicMessageStore: Step {
    
    /// The relay property for maintaining message history
    @Relay var messages: [MessageParameter.Message]
    
    /// Adds a user message to the message history.
    ///
    /// - Parameter input: The message content to store
    /// - Returns: The original input message
    func run(_ input: String) async throws -> String {
        messages.append(.init(role: .user, content: .text(input)))
        return input
    }
}

/// A step that transforms messages for the Anthropic model.
///
/// This step handles adding assistant responses to the message history.
struct AnthropicMessageTransform: Step {
    
    /// The relay property for maintaining message history
    @Relay var messages: [MessageParameter.Message]
    
    /// Transforms and stores assistant messages.
    ///
    /// - Parameter input: The assistant's response to store
    /// - Returns: The complete message history
    func run(_ input: String) async throws -> [MessageParameter.Message] {
        messages.append(.init(role: .assistant, content: .text(input)))
        return messages
    }
}

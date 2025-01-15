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
public struct AnthropicModel: SwiftAgent.Model {
    
    /// The input type for the model, consisting of an array of messages.
    public typealias Input = [MessageParameter.Message]
    
    /// The output type for the model, represented as a String response.
    public typealias Output = String
    
    // The underlying Anthropic service client
    private let service: AnthropicService
    
    /// The specific Anthropic model to use for generation (e.g., Claude 3 Haiku).
    public var model: SwiftAnthropic.Model
    
    /// An array of tools available to the model for executing various tasks.
    public var tools: [any Tool]
    
    /// The system prompt that provides initial context and instructions to the model.
    public var systemPrompt: String
    
    /// Creates a new instance of AnthropicModel.
    ///
    /// - Parameters:
    ///   - model: The specific Anthropic model to use. Defaults to claude35Haiku.
    ///   - tools: An array of tools that the model can use during execution.
    ///   - systemPrompt: A closure that generates the system prompt based on available tools.
    /// - Throws: Fatal error if ANTHROPIC_API_KEY environment variable is not set.
    public init(
        model: SwiftAnthropic.Model = .claude35Haiku,
        tools: [any Tool] = [],
        systemPrompt: ([any Tool]) -> String
    ) {
        guard let apiKey: String = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] else {
            fatalError("Anthropic API Key is not set in environment variables.")
        }
        self.model = model
        self.tools = tools
        self.service = AnthropicServiceFactory.service(apiKey: apiKey, betaHeaders: nil)
        self.systemPrompt = systemPrompt(tools)
    }
    
    /// Executes the model with the provided input messages.
    ///
    /// This method handles:
    /// - Converting tools to Anthropic's expected format
    /// - Streaming responses from the model
    /// - Processing tool calls and their results
    /// - Aggregating the complete response
    ///
    /// - Parameter input: An array of messages to process
    /// - Returns: The complete response from the model as a string
    /// - Throws: ModelError or underlying API errors
    public func run(_ input: [MessageParameter.Message]) async throws -> String {
        // Convert tools to Anthropic format
        let anthropicTools = tools.map { tool in
            MessageParameter.Tool(
                name: tool.name,
                description: tool.description,
                inputSchema: try? JSONSchema.from(tool.parameters)
            )
        }
        
        // Build request parameters
        let parameters = MessageParameter(
            model: model,
            messages: input,
            maxTokens: 4096,
            system: .text(systemPrompt),
            tools: anthropicTools
        )
        
        var completeResponse = ""
        
        let stream = try await service.streamMessage(parameters)
        
        // Process streaming response
        for try await response in stream {
            switch response.type {
            case MessageStreamResponse.StreamEvent.contentBlockDelta.rawValue:
                if let text = response.delta?.text {
                    completeResponse += text
                }
                
            case MessageStreamResponse.StreamEvent.contentBlockStart.rawValue:
                if let contentBlock = response.contentBlock,
                   contentBlock.type == "tool_use",
                   let toolUse = contentBlock.toolUse {
                    if let result = try await executeToolCall(toolUse) {
                        completeResponse += "\nTool result: \(result)"
                    }
                }
                
            default:
                break
            }
        }
        
        return completeResponse
    }
    
    /// Executes a tool call based on the model's request.
    ///
    /// - Parameter toolUse: The tool use request from the model
    /// - Returns: The result of the tool execution as a string
    /// - Throws: ModelError.toolNotFound if the requested tool doesn't exist
    private func executeToolCall(_ toolUse: MessageResponse.Content.ToolUse) async throws -> String? {
        guard let tool = tools.first(where: { $0.name == toolUse.name }) else {
            throw ModelError.toolNotFound(toolUse.name)
        }
        return try await tool.call(toolUse.input)
    }
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

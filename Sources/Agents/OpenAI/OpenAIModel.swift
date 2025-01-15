//
//  OpenAIModel.swift
//  SwiftAgent
//
//  Created by Norikazu Muramoto on 2025/01/13.
//

import Foundation
import SwiftAgent
import AgentTools
import LLMChatOpenAI

/// A concrete implementation of the Model protocol using LLMChatOpenAI.
public struct OpenAIModel<Output: Sendable>: SwiftAgent.Model {
    public typealias Input = [ChatMessage]
    
    /// The identifier for the OpenAI model to use
    public let model: String
    
    /// An array of tools available to the model
    public let tools: [any Tool]
    
    /// The system prompt that provides initial context
    public let systemPrompt: String
    
    /// The endpoint URL for API calls
    private let endpoint: URL?
    
    /// Options for chat completion
    private let options: ChatOptions
    
    /// The LLMChatOpenAI client instance
    private let client: LLMChatOpenAI
    
    /// Response parser for converting JSON to Output type
    private let responseParser: (String) throws -> Output
    
    /// Creates a new instance of OpenAIModel for text output
    public init(
        model: String = "gpt-4o-mini",
        endpoint: URL? = nil,
        options: ChatOptions? = nil,
        tools: [any Tool] = [],
        systemPrompt: ([any Tool]) -> String
    ) where Output == String {
        let initialSystemPrompt = systemPrompt(tools)
        
        // Configure tools and options
        let initialOptions: ChatOptions
        if tools.isEmpty {
            initialOptions = options ?? ChatOptions()
        } else {
            let toolOptions = tools.map { tool in
                ChatOptions.Tool(
                    type: "function",
                    function: .init(
                        name: tool.name,
                        description: tool.description,
                        parameters: tool.parameters
                    )
                )
            }
            
            initialOptions = ChatOptions(
                frequencyPenalty: options?.frequencyPenalty,
                logitBias: options?.logitBias,
                topLogprobs: options?.topLogprobs,
                maxCompletionTokens: options?.maxCompletionTokens,
                n: options?.n,
                presencePenalty: options?.presencePenalty,
                responseFormat: options?.responseFormat,
                seed: options?.seed,
                stop: options?.stop,
                temperature: options?.temperature,
                topP: options?.topP,
                tools: toolOptions,
                toolChoice: options?.toolChoice,
                user: options?.user
            )
        }
        
        self.model = model
        self.tools = tools
        self.systemPrompt = initialSystemPrompt
        self.endpoint = endpoint
        self.options = initialOptions
        self.client = LLMChatOpenAI(apiKey: ProcessInfo.processInfo.environment["OPENAI_API_KEY"]!, endpoint: endpoint)
        self.responseParser = { $0 }
    }
    
    /// Creates a new instance of OpenAIModel with a Codable output type
    public init(
        model: String = "gpt-4o-mini",
        endpoint: URL? = nil,
        options: ChatOptions? = nil,
        schema: JSONSchema,
        tools: [any Tool] = [],
        systemPrompt: ([any Tool]) -> String
    ) where Output: Codable {
        let initialSystemPrompt = systemPrompt(tools)
        
        // Configure response format with schema
        let schemaFormat = ChatOptions.ResponseFormat(
            type: .jsonSchema,
            jsonSchema: .init(
                name: "response_schema",
                description: "Response format schema",
                schema: schema,
                strict: true
            )
        )
        
        // Configure tools and options
        let toolOptions = tools.map { tool in
            ChatOptions.Tool(
                type: "function",
                function: .init(
                    name: tool.name,
                    description: tool.description,
                    parameters: tool.parameters
                )
            )
        }
        
        let initialOptions = ChatOptions(
            frequencyPenalty: options?.frequencyPenalty,
            logitBias: options?.logitBias,
            topLogprobs: options?.topLogprobs,
            maxCompletionTokens: options?.maxCompletionTokens,
            n: options?.n,
            presencePenalty: options?.presencePenalty,
            responseFormat: schemaFormat,
            seed: options?.seed,
            stop: options?.stop,
            temperature: options?.temperature,
            topP: options?.topP,
            tools: toolOptions.isEmpty ? nil : toolOptions,
            toolChoice: options?.toolChoice,
            user: options?.user
        )
        
        self.model = model
        self.tools = tools
        self.systemPrompt = initialSystemPrompt
        self.endpoint = endpoint
        self.options = initialOptions
        self.client = LLMChatOpenAI(apiKey: ProcessInfo.processInfo.environment["OPENAI_API_KEY"]!, endpoint: endpoint)
        self.responseParser = { jsonString in
            guard let data = jsonString.data(using: .utf8) else {
                throw OpenAIModelError.invalidResponse
            }
            return try JSONDecoder().decode(Output.self, from: data)
        }
    }
    
    /// Executes the model with the provided input messages
    public func run(_ input: Input) async throws -> Output {
        var messages = input
        if !messages.contains(where: { $0.role == .system }) {
            messages.insert(ChatMessage(role: .system, content: systemPrompt), at: 0)
        }
        
        do {
            let response = try await client.send(
                model: model,
                messages: messages,
                options: options
            )
            
            if let toolCalls = response.choices.first?.message.toolCalls {
                var results: [String] = []
                for toolCall in toolCalls {
                    if let tool = tools.first(where: { $0.name == toolCall.function.name }) {
                        if let argumentsData = toolCall.function.arguments.data(using: .utf8) {
                            let result = try await tool.call(data: argumentsData)
                            results.append(result)
                        }
                    }
                }
                return try responseParser(results.joined(separator: "\n"))
            }
            
            if let content = response.choices.first?.message.content {
                return try responseParser(content)
            } else if let refusal = response.choices.first?.message.refusal {
                throw OpenAIModelError.modelRefused(refusal)
            }
            
            throw OpenAIModelError.noContent
            
        } catch let error as LLMChatOpenAIError {
            throw error
        } catch let error as OpenAIModelError {
            throw error
        } catch {
            throw LLMChatOpenAIError.networkError(error)
        }
    }
}

/// Errors specific to OpenAIModel
public enum OpenAIModelError: Error {
    case invalidResponse
    case noContent
    case modelRefused(String)
}

// MARK: - Type Safe Response Extensions

extension OpenAIModel where Output: Codable {
    /// Creates a new instance with updated response schema
    public func withResponseSchema(_ schema: JSONSchema) -> Self {
        let schemaFormat = ChatOptions.ResponseFormat(
            type: .jsonSchema,
            jsonSchema: .init(
                name: "response_schema",
                description: "Response format schema",
                schema: schema,
                strict: true
            )
        )
        
        let newOptions = ChatOptions(
            frequencyPenalty: options.frequencyPenalty,
            logitBias: options.logitBias,
            topLogprobs: options.topLogprobs,
            maxCompletionTokens: options.maxCompletionTokens,
            n: options.n,
            presencePenalty: options.presencePenalty,
            responseFormat: schemaFormat,
            seed: options.seed,
            stop: options.stop,
            temperature: options.temperature,
            topP: options.topP,
            tools: options.tools,
            toolChoice: options.toolChoice,
            user: options.user
        )
        
        return OpenAIModel(
            model: self.model,
            endpoint: self.endpoint,
            options: newOptions,
            schema: schema,
            tools: self.tools,
            systemPrompt: { _ in self.systemPrompt }            
        )
    }
}

// MARK: - Message Transform Steps

public struct OpenAIMessageStore: Step {
    public typealias Input = String
    public typealias Output = String
    
    @Relay var messages: [ChatMessage]
    
    public func run(_ input: Input) async throws -> Output {
        messages.append(ChatMessage(role: .assistant, content: input))
        return input
    }
}

public struct OpenAIMessageTransform: Step {
    public typealias Input = String
    public typealias Output = [ChatMessage]
    
    @Relay var messages: [ChatMessage]
    
    public func run(_ input: Input) async throws -> Output {
        messages.append(ChatMessage(role: .user, content: input))
        return messages
    }
}

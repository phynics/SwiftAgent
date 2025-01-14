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

/// OpenAI based implementation of Model
public struct OpenAIModel: SwiftAgent.Model {
    
    public var model: String
    
    public var tools: [any Tool]
    
    public var systemPrompt: String
    
    private let openAI: OpenAI
    
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
        
        // レスポンス処理を continuation の外で行う
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

public struct OpenAIMessageStore: Step {
    
    @Relay var messages: [ChatQuery.ChatCompletionMessageParam]
    
    public func run(_ input: String) async throws -> String {
        messages.append(.assistant(.init(content: input)))
        return input
    }
}

public struct OpenAIMessageTransform: Step {
    
    @Relay var messages: [ChatQuery.ChatCompletionMessageParam]
    
    public func run(_ input: String) async throws -> [ChatQuery.ChatCompletionMessageParam] {
        messages.append(.user(.init(content: .string(input))))
        return messages
    }
}

extension ChatResult: @retroactive @unchecked Sendable {}

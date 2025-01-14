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

/// SwiftAnthropic based implementation of Model protocol
public struct AnthropicModel: SwiftAgent.Model {
    
    public typealias Input = [MessageParameter.Message]
    public typealias Output = String
    
    // Anthropicサービス
    private let service: AnthropicService
    
    public var model: SwiftAnthropic.Model
    
    // ツール配列
    public var tools: [any Tool]
    
    // システムプロンプト
    public var systemPrompt: String
    
    /// イニシャライザ
    /// - Parameters:
    ///   - apiKey: Anthropic API Key
    ///   - systemPrompt: システムプロンプトを生成する関数
    public init(
        model: SwiftAnthropic.Model = .claude35Haiku,
        tools: [any Tool],
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
    
    public func run(_ input: [MessageParameter.Message]) async throws -> String {
        // メッセージのマッピング
        let messages = input
        
        // ツールの変換
        let anthropicTools = tools.map { tool in
            MessageParameter.Tool(
                name: tool.name,
                description: tool.description,
                inputSchema: try? JSONSchema.from(tool.parameters)
            )
        }
        
        // パラメータの構築
        let parameters = MessageParameter(
            model: model,
            messages: messages,
            maxTokens: 4096,
            system: .text(systemPrompt),
            tools: anthropicTools
        )
        
        var completeResponse = ""
        
        let stream = try await service.streamMessage(parameters)
        
        // ストリーミングレスポンスの処理
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
    
    
    private func executeToolCall(_ toolUse: MessageResponse.Content.ToolUse) async throws -> String? {
        guard let tool = tools.first(where: { $0.name == toolUse.name }) else {
            throw ModelError.toolNotFound(toolUse.name)
        }
        return try await tool.call(toolUse.input)
    }
}

// MARK: - Error Types

public enum ModelError: LocalizedError {
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
    static func from(_ schema: JSONSchema) throws -> MessageParameter.Tool.JSONSchema {
        let type = convertJSONType(schema.type)
        let description = schema.description
        
        // プロパティの変換（オブジェクトタイプの場合）
        var properties: [String: MessageParameter.Tool.JSONSchema.Property] = [:]
        if case .object = schema.type {
            // 基本的なプロパティを設定
            let property = MessageParameter.Tool.JSONSchema.Property(
                type: type,
                description: description
            )
            properties["value"] = property
        }
        
        return MessageParameter.Tool.JSONSchema(
            type: type,
            properties: properties,
            required: []  // 必要に応じて設定
        )
    }
    
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
            return .string // nullとenumはstringとして扱う
        }
    }
    
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


struct AnthropicMessageStore: Step {
    
    @Relay var messages: [MessageParameter.Message]
    
    func run(_ input: String) async throws -> String {
        messages.append(.init(role: .user, content: .text(input)))
        return input
    }
}


struct AnthropicMessageTransform: Step {
    
    @Relay var messages: [MessageParameter.Message]
    
    func run(_ input: String) async throws -> [MessageParameter.Message] {
        messages.append(.init(role: .assistant, content: .text(input)))
        return messages
    }
}

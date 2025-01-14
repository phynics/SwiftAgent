//
//  AnthropicAgent.swift
//  SwiftAgent
//
//  Created by Norikazu Muramoto on 2025/01/13.
//


import Foundation
import SwiftAgent
import SwiftAnthropic

/// Enhanced agent implementation using Ollama model
public struct AnthropicAgent: Agent {
    
    public typealias Input = String
    
    public typealias Output = String
    
    @Memory private var messages: [MessageParameter.Message] = []
    
    public init() {}
    
    public var body: some Step<Input, Output> {
        AnthropicMessageTransform(messages: $messages)
        AnthropicModel { tools in
            PromptTemplates()
                .systemPrompt(
                    tools: tools,
                    workingDirectory: FileManager.default.currentDirectoryPath,
                    systemInfo: SystemInfo()
                )
        }
        .log { input in
            if let last = input.last {
                switch last.content {
                case .text(let text): return "User: \(text)"
                default: return "x"
                }
            }
            return "-"
        } outputTransform: { output in
            return "Assistant: \(output)"
        }
        AnthropicMessageStore(messages: $messages)
    }
}

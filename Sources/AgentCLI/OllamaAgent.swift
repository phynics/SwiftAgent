//
//  OllamaAgent.swift
//  SwiftAgent
//
//  Created by Assistant on 2025/01/11.
//

import Foundation
import SwiftAgent
import SwiftUI
import OllamaKit

/// Enhanced agent implementation using Ollama model
public struct OllamaAgent: Agent {

    public typealias Input = String
    
    public typealias Output = String
    
    @Memory private var messages: [OKChatRequestData.Message] = []
        
    public init() {}
    
    public var body: some Step<Input, Output> {
        Loop(max: 3) { input in
            MessageTransform(messages: $messages)
            OllamaModel { tools in
                PromptTemplates()
                    .systemPrompt(
                        tools: tools,
                        workingDirectory: FileManager.default.currentDirectoryPath,
                        systemInfo: SystemInfo()
                    )
            }
            .log { input in
                return "User: \(input.last?.content ?? "")"
            } outputTransform: { output in
                return "Assistant: \(output)"
            }
            MessageStore(messages: $messages)
        } until: { output in
            return false
        }
    }
}

struct MessageStore: Step {
    
    @Relay var messages: [OKChatRequestData.Message]

    func run(_ input: String) async throws -> String {
        messages.append(.assistant(input))
        return input
    }
}


struct MessageTransform: Step {
    
    @Relay var messages: [OKChatRequestData.Message]
    
    func run(_ input: String) async throws -> [OKChatRequestData.Message] {
        messages.append(.user(input))
        return messages
    }
}

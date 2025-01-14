//
//  OllamaAgent.swift
//  SwiftAgent
//
//  Created by Assistant on 2025/01/11.
//

import Foundation
import SwiftAgent
import OllamaKit

/// Enhanced agent implementation using Ollama model
public struct OllamaAgent: Agent {

    public typealias Input = String
    
    public typealias Output = String
    
    @Memory private var messages: [OKChatRequestData.Message] = []
        
    public init() {}
    
    public var body: some Step<Input, Output> {
        OllamaMessageTransform(messages: $messages)
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
        OllamaMessageStore(messages: $messages)
    }
}

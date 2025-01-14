//
//  OpenAIAgent.swift
//  SwiftAgent
//
//  Created by Norikazu Muramoto on 2025/01/13.
//


import Foundation
import SwiftAgent
import OpenAI
import AgentTools

/// Enhanced agent implementation using Ollama model
public struct OpenAIAgent: Agent {
    
    public typealias Input = String
    
    public typealias Output = String
    
    @Memory private var messages: [ChatQuery.ChatCompletionMessageParam] = []
    
    public init() {}
    
    public var body: some Step<Input, Output> {
        OpenAIMessageTransform(messages: $messages)
        OpenAIModel(tools: [
            FileSystemTool(workingDirectory: FileManager.default.currentDirectoryPath),
            ExecuteCommandTool()
        ]) { tools in
            PromptTemplates()
                .systemPrompt(
                    tools: tools,
                    workingDirectory: FileManager.default.currentDirectoryPath,
                    systemInfo: SystemInfo()
                )
        }
        .log { input in
            return "User: \(input.last?.content?.string ?? "")"
        } outputTransform: { output in
            return "Assistant: \(output)"
        }
        OpenAIMessageStore(messages: $messages)
    }
}

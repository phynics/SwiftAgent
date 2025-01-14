//
//  AnthropicAgent.swift
//  SwiftAgent
//
//  Created by Norikazu Muramoto on 2025/01/13.
//


import Foundation
import SwiftAgent
import SwiftAnthropic
import AgentTools

/// Enhanced agent implementation using Ollama model
public struct AnthropicAgent: Agent {
    
    public typealias Input = String
    
    public typealias Output = String
    
    @Memory private var messages: [MessageParameter.Message] = []
    
    public init() {}
    
    public var body: some Step<Input, Output> {
        AnthropicMessageTransform(messages: $messages)
        AnthropicModel(tools: [
            FileSystemTool(workingDirectory: FileManager.default.currentDirectoryPath),
            ExecuteCommandTool()
        ]) { tools in
            PromptTemplates
                .systemPrompt(
                    tools: tools,
                    workingDirectory: FileManager.default.currentDirectoryPath,
                    systemInfo: SystemInfo()
                )
        }
        .monitor(
            input: { input in
                print("Step received input: \(input)")
            },
            output: { output in
                print("Step produced output: \(output)")
            }
        )
        AnthropicMessageStore(messages: $messages)
    }
}

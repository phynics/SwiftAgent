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
    
    var prompt: String?
    
    /// Creates a new instance of Agent.
    public init(_ prompt: String? = nil) {
        self.prompt = prompt
    }
    
    public var body: some Step<Input, Output> {
        AnthropicMessageTransform(messages: $messages)
        AnthropicModel(tools: [
            ExecuteCommandTool(),
            URLFetchTool(),
            FileSystemTool(workingDirectory: FileManager.default.currentDirectoryPath),
            GitTool()
        ]) { tools in
            prompt ?? PromptTemplates
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

//
//  OllamaAgent.swift
//  SwiftAgent
//
//  Created by Assistant on 2025/01/11.
//

import Foundation
import SwiftAgent
import OllamaKit
import AgentTools

/// Enhanced agent implementation using Ollama model
public struct OllamaAgent: Agent {

    public typealias Input = String
    
    public typealias Output = String
    
    @Memory private var messages: [OKChatRequestData.Message] = []
        
    var prompt: String?
    
    /// Creates a new instance of Agent.
    public init(_ prompt: String? = nil) {
        self.prompt = prompt
    }
    
    public var body: some Step<Input, Output> {
        OllamaMessageTransform(messages: $messages)
        OllamaModel(tools: [
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
        OllamaMessageStore(messages: $messages)
    }
}

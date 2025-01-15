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
        
    public init() {}
    
    public var body: some Step<Input, Output> {
        OllamaMessageTransform(messages: $messages)
        OllamaModel(tools: [
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
        OllamaMessageStore(messages: $messages)
    }
}

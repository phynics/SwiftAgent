//
//  OllamaModel.swift
//  SwiftAgent
//
//  Created by Norikazu Muramoto on 2025/01/11.
//

import Foundation
import SwiftAgent
import AgentTools
import OllamaKit

/// OllamaKit based implementation of Model
public struct OllamaModel: Model {
    
    public typealias Input = [OKChatRequestData.Message]
    public typealias Output = String
    
    public var tools: [any Tool] = [
        FileSystemTool(workingDirectory: FileManager.default.currentDirectoryPath),
        ExecuteCommandTool()
    ]
    
    public var systemPrompt: String
        
    public init(
        _ systemPrompt: ([any Tool]) -> String
    ) {
        self.systemPrompt = systemPrompt(tools)
    }
    
    public func run(_ input: [OKChatRequestData.Message]) async throws -> String {
        let okTools: [OKTool] = tools.map { tool -> OKTool in
                .function(
                    OKFunction(
                        name: tool.name,
                        description: tool.description,
                        parameters: tool.parameters
                    )
                )
        }
        
        let messages: [OKChatRequestData.Message] = [.system(systemPrompt)] + input
        let ollama = OllamaKit()
        let stream: AsyncThrowingStream<OKChatResponse, Error> = ollama.chat(
            data: .init(
                model: "llama3.2:latest",
                messages: messages,
                tools: okTools
            )
        )
        
        var output = ""
        var toolResults: [String] = []
        
        for try await response in stream {
            if let message = response.message {
                // Add content to output
                output += message.content
                
                // Handle tool calls
                if let toolCalls = message.toolCalls {
                    for toolCall in toolCalls {
                        if let result = try await processToolCall(toolCall) {
                            toolResults.append(result)
                        }
                    }
                }
            }
            
            if response.done {
                break
            }
        }
        
        // If there were tool results, append them to the output
        if !toolResults.isEmpty {
            output += "\n\nTool Results:\n" + toolResults.joined(separator: "\n")
        }
        
        return output
    }
    
    private func processToolCall(_ toolCall: OKChatResponse.Message.ToolCall) async throws -> String? {
        guard let function = toolCall.function,
              let name = function.name,
              let arguments = function.arguments,
              let tool = tools.first(where: { $0.name == name }) else {
            return nil
        }
        return try await tool.call(arguments)
    }
}

// Helper types for message handling
public struct OllamaMessageStore: Step {
    @Relay var messages: [OKChatRequestData.Message]
    
    public func run(_ input: String) async throws -> String {
        messages.append(.assistant(input))
        return input
    }
}

public struct OllamaMessageTransform: Step {
    @Relay var messages: [OKChatRequestData.Message]
    
    public func run(_ input: String) async throws -> [OKChatRequestData.Message] {
        messages.append(.user(input))
        return messages
    }
}

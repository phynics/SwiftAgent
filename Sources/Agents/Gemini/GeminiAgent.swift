//
//  GeminiAgent.swift
//  SwiftAgent
//
//  Created by Norikazu Muramoto on 2025/02/05.
//

import Foundation
import SwiftAgent
import AgentTools
@preconcurrency import GoogleGenerativeAI

/// An agent implementation that leverages Google's Gemini model.
///
/// `GeminiAgent` provides a declarative way to build conversation flows using Gemini,
/// with integrated tool support and conversation history management.
///
/// Example usage:
/// ```swift
/// let agent = GeminiAgent()
/// let response = try await agent.run("Analyze this code repository")
/// ```
public struct GeminiAgent: Agent {
    public typealias Input = String
    public typealias Output = String
    
    /// Stores the conversation history as Gemini messages
    @Memory private var messages: [ModelContent] = []
    
    /// Optional custom system prompt
    var prompt: String?
    
    /// Creates a new instance of GeminiAgent
    /// - Parameter prompt: Optional custom system prompt to override the default
    public init(_ prompt: String? = nil) {
        self.prompt = prompt
    }
    
    /// The processing pipeline for the agent
    public var body: some Step<String, String> {
        // Transform input into Gemini message format
        GeminiMessageTransform(messages: $messages)
        
        // Process with Gemini model and available tools
        GeminiModel(
            modelName: "gemini-2.0-pro-exp-02-05",
            temperature: 0.7,
            tools: createTools()
        ) { tools in
            prompt ?? PromptTemplates
                .systemPrompt(
                    tools: tools,
                    workingDirectory: FileManager.default.currentDirectoryPath,
                    systemInfo: SystemInfo()
                )
        }
        
        // Store the response in conversation history
        GeminiMessageStore(messages: $messages)
    }
    
    /// Creates the default set of tools available to the agent
    private func createTools() -> [any SwiftAgent.Tool] {
        return [
            ExecuteCommandTool(),
            URLFetchTool(),
            FileSystemTool(workingDirectory: FileManager.default.currentDirectoryPath),
            GitTool()
        ]
    }
}

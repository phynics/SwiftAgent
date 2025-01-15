//
//  OpenAIAgent.swift
//  SwiftAgent
//
//  Created by Norikazu Muramoto on 2025/01/13.
//

import Foundation
import SwiftAgent
import LLMChatOpenAI
import AgentTools

/// An agent implementation that leverages OpenAI's models with enhanced functionality.
///
/// `OpenAIAgent` provides a declarative way to build conversation flows using OpenAI's models,
/// with integrated file system access and command execution capabilities.
///
/// The agent maintains conversation history and supports monitoring of each step's
/// input and output for debugging purposes.
///
/// Example usage:
/// ```swift
/// let agent = OpenAIAgent()
/// let response = try await agent.run("List all files in the current directory")
/// ```
///
/// The agent's processing pipeline consists of:
/// 1. Message transformation for OpenAI format
/// 2. Model execution with available tools
/// 3. Message storage for conversation history
public struct OpenAIAgent: Agent {
    
    /// Stores the conversation history as OpenAI chat messages.
    ///
    /// The conversation history is maintained across multiple interactions
    /// to provide context for the model's responses.
    @Memory private var messages: [ChatMessage] = []
    
    /// Creates a new instance of OpenAIAgent.
    public init() {}
    
    /// The processing pipeline for the agent.
    ///
    /// This property defines the sequence of steps that process each input:
    /// - Transforms input into OpenAI message format
    /// - Processes the message using the OpenAI model with available tools
    /// - Monitors the processing for debugging
    /// - Stores the response in conversation history
    ///
    /// Available tools include:
    /// - FileSystemTool: For file system operations
    /// - ExecuteCommandTool: For executing system commands
    ///
    /// The model uses a system prompt that includes:
    /// - Tool descriptions and capabilities
    /// - Working directory information
    /// - System information
    public var body: some Step<String, String> {
        OpenAIMessageTransform(messages: $messages)
        OpenAIModel(tools: [
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
        OpenAIMessageStore(messages: $messages)
    }
}

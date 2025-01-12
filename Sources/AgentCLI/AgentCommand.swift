//
//  AgentCommand.swift
//  SwiftAgent
//
//  Created by Assistant on 2025/01/11.
//

import Foundation
import ArgumentParser
import SwiftAgent
import OllamaKit
import AgentTools

@main
struct AgentCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "agent",
        abstract: "AI Agent Command Line Tool",
        version: "1.0.0",
        subcommands: [Ask.self],
        defaultSubcommand: Ask.self
    )
    
    /// Ask subcommand for querying the agent
    struct Ask: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "ask",  // これも変えた方がいいかもしれません
            abstract: "Send a prompt or task to the agent"
        )
        
        @Argument(help: "The prompt or task for the agent")
        var prompt: String
        
        @Argument(help: "Maximum number of steps")
        var maxSteps: Int = 10
        
        @Argument(help: "Ollama model to use")
        var model: String = "phi4:latest"
        
        @Argument(help: "Ollama base URL")
        var baseURL: String = "http://localhost:11434"
        
        @Flag(name: .shortAndLong, help: "Show detailed thought process")
        var verbose: Bool = false
        
        @Flag(name: .shortAndLong, help: "Show only the final answer")
        var quiet: Bool = false
        
        // Available tools
        
        mutating func run() async throws {
            guard !prompt.isEmpty else {
                throw ValidationError("Prompt cannot be empty")
            }
            
            let output = try await OllamaAgent().run(prompt)
            print(output)
        }
    }
}

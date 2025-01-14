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

/// A command-line interface for interacting with AI agents.
///
/// `AgentCommand` serves as the main entry point for the CLI application, providing
/// commands to interact with AI agents through the terminal.
///
/// Example usage:
/// ```bash
/// # Basic query
/// agent ask "What is the weather today?"
///
/// # Query with maximum steps
/// agent ask "Plan my vacation" 20
///
/// # Query with quiet mode
/// agent ask --quiet "Summarize this document"
/// ```
@main
struct AgentCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "agent",
        abstract: "AI Agent Command Line Tool",
        version: "1.0.0",
        subcommands: [Ask.self],
        defaultSubcommand: Ask.self
    )
    
    /// A subcommand that sends queries or tasks to the AI agent.
    ///
    /// The `Ask` command allows users to interact with the AI agent by sending prompts
    /// or tasks and receiving responses. It supports various options to customize the
    /// interaction, such as setting maximum steps and controlling output verbosity.
    ///
    /// Example usage:
    /// ```bash
    /// # Basic query
    /// agent ask "What is the capital of France?"
    ///
    /// # Set maximum steps
    /// agent ask "Plan a week-long trip" 15
    ///
    /// # Use quiet mode for minimal output
    /// agent ask --quiet "Calculate 2 + 2"
    /// ```
    struct Ask: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "ask",
            abstract: "Send a prompt or task to the agent"
        )
        
        /// The prompt or task to send to the agent.
        ///
        /// This argument specifies the text input that will be processed by the AI agent.
        /// It can be a question, task description, or any other input the agent is designed
        /// to handle.
        @Argument(help: "The prompt or task for the agent")
        var prompt: String
        
        /// The maximum number of processing steps the agent can take.
        ///
        /// This argument limits how many steps the agent can take while processing the prompt,
        /// preventing infinite loops or excessive processing time. Defaults to 10 steps.
        @Argument(help: "Maximum number of steps")
        var maxSteps: Int = 10
        
        /// A flag to control output verbosity.
        ///
        /// When set, only the final answer is displayed, omitting intermediate steps
        /// and processing information.
        @Flag(name: .shortAndLong, help: "Show only the final answer")
        var quiet: Bool = false
        
        /// Executes the ask command with the provided arguments.
        ///
        /// This method validates the input and runs the agent with the specified prompt,
        /// respecting the maximum steps and quiet mode settings.
        ///
        /// - Throws: ValidationError if the prompt is empty
        /// - Throws: Any error that occurs during agent execution
        mutating func run() async throws {
            guard !prompt.isEmpty else {
                throw ValidationError("Prompt cannot be empty")
            }
            let output = try await MainAgent().run(prompt)
            print(output)
        }
    }
}

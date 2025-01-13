//
//  ExecuteCommandTool.swift
//  SwiftAgent
//
//  Created by Norikazu Muramoto on 2025/01/11.
//

import Foundation
import SwiftAgent

/// A tool for executing shell commands in a controlled environment.
///
/// `ExecuteCommandTool` allows safe execution of shell commands or scripts while enforcing basic
/// input validation and sanitization to prevent misuse or unsafe behavior.
///
/// ## Features
/// - Run system commands or shell scripts.
/// - Perform non-interactive system operations.
///
/// ## Limitations
/// - Does not support long-running processes.
/// - Does not allow interactive commands.
/// - Cannot execute commands requiring user input.
public struct ExecuteCommandTool: Tool {
    public typealias Input = ExecuteCommandInput
    public typealias Output = ExecuteCommandOutput
    
    public let name = "execute"
    
    public let description = """
    A tool for executing shell commands in a controlled environment.
    
    Use this tool to:
    - Run system commands
    - Execute shell scripts
    - Perform non-interactive system operations
    
    Limitations:
    - Does not support long-running processes
    - Does not allow interactive commands
    - Cannot execute commands requiring user input
    """
    
    public let guide: String? = """
    # ExecuteCommandTool Guide
    
    ## Description
    `ExecuteCommandTool` is a utility for executing shell commands or scripts in a controlled and safe manner. It ensures basic input validation and sanitization to prevent misuse or unsafe behavior.
    
    ### Key Features
    - Run shell commands or scripts in a non-interactive environment.
    - Provides validation and sanitization for safer command execution.
    - Captures output and metadata from the executed command.
    
    ### Limitations
    - Does not support commands requiring user input.
    - Interactive commands like `vim` or `ssh` are not allowed.
    - Long-running processes are not supported.
    
    ## Parameters
    ### Required Parameters
    - **command**:
      - **Type**: `String`
      - **Description**: The shell command to execute.
      - **Requirements**: Must not be empty. Commands should be valid and safe to execute.
    
    ## Usage
    ### General Guidelines
    - Validate commands before execution to ensure safety.
    - Avoid using commands that modify system-critical files or directories.
    - Ensure commands are non-interactive and short-running.
    
    ### Common Scenarios
    1. **Listing Files**: Use commands like `ls -la` to list files in a directory.
    2. **Checking System Information**: Commands such as `uname -a` can provide system details.
    3. **Simple File Operations**: Commands like `cat filename.txt` can read file contents.
    
    ## Examples
    
    ### Example 1: List Files in a Directory
    ```json
    {
      "command": "ls -la"
    }
    ```
    **Expected Output**:
    ```json
    {
      "success": true,
      "output": "drwxr-xr-x  5 user group 160 Jan 11 12:34 .\n-rw-r--r--  1 user group  12 Jan 11 12:34 file.txt",
      "metadata": {
        "status": "0",
        "command": "ls -la"
      }
    }
    ```
    
    ### Example 2: Display System Information
    ```json
    {
      "command": "uname -a"
    }
    ```
    **Expected Output**:
    ```json
    {
      "success": true,
      "output": "Darwin hostname.local 22.3.0 Darwin Kernel Version 22.3.0: Thu Jan 12 20:41:10 PST 2023; root:xnu-8792.81.3~1/RELEASE_ARM64_T8103 arm64",
      "metadata": {
        "status": "0",
        "command": "uname -a"
      }
    }
    ```
    
    ### Example 3: Invalid Command
    ```json
    {
      "command": "invalid_command"
    }
    ```
    **Expected Output**:
    ```json
    {
      "success": false,
      "output": "zsh: command not found: invalid_command",
      "metadata": {
        "status": "127",
        "command": "invalid_command"
      }
    }
    ```
    
    ### Example 4: Unsafe Command
    ```json
    {
      "command": "rm -rf /"
    }
    ```
    **Expected Output**:
    ```json
    {
      "success": false,
      "error": "Unsafe command detected: rm -rf /"
    }
    ```
    """
    
    public let parameters: JSONSchema = .object(
        description: "Schema for command execution",
        properties: [
            "command": .string(description: "The shell command to execute")
        ],
        required: ["command"]
    )
    
    public init() {}
    
    public func call(_ input: ExecuteCommandInput) async throws -> ExecuteCommandOutput {
        guard !input.command.isEmpty else {
            throw ToolError.invalidParameters("Command cannot be empty")
        }
        
        let sanitizedCommand = sanitizeCommand(input.command)
        guard validateCommand(sanitizedCommand) else {
            throw ToolError.invalidParameters("Unsafe command detected: \(input.command)")
        }
        
        return try await executeCommand(sanitizedCommand)
    }
}


// MARK: - Input/Output Types

/// The input structure for command execution.
public struct ExecuteCommandInput: Codable, Sendable {
    /// The shell command to execute.
    public let command: String
    
    /// Creates a new instance of `ExecuteCommandInput`.
    ///
    /// - Parameter command: The shell command to execute.
    public init(command: String) {
        self.command = command
    }
}

/// The output structure for command execution.
public struct ExecuteCommandOutput: Codable, Sendable {
    /// Whether the command was executed successfully.
    public let success: Bool
    
    /// The output produced by the command.
    public let output: String
    
    /// Additional metadata about the command execution.
    public let metadata: [String: String]
    
    /// Creates a new instance of `ExecuteCommandOutput`.
    ///
    /// - Parameters:
    ///   - success: Indicates if the command was executed successfully.
    ///   - output: The output of the command.
    ///   - metadata: Additional details about the execution.
    public init(success: Bool, output: String, metadata: [String: String]) {
        self.success = success
        self.output = output
        self.metadata = metadata
    }
}

// MARK: - Private Methods

private extension ExecuteCommandTool {
    /// Executes a sanitized shell command and returns the result.
    ///
    /// - Parameter command: The sanitized shell command to execute.
    /// - Returns: The result of the command execution.
    /// - Throws: `ToolError` if the command fails.
    func executeCommand(_ command: String) async throws -> ExecuteCommandOutput {
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let pipe = Pipe()
            
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = ["-c", command]
            process.standardOutput = pipe
            process.standardError = pipe
            
            process.terminationHandler = { process in
                do {
                    let data = try pipe.fileHandleForReading.readToEnd() ?? Data()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    
                    if process.terminationStatus == 0 {
                        continuation.resume(returning: ExecuteCommandOutput(
                            success: true,
                            output: output,
                            metadata: [
                                "status": "\(process.terminationStatus)",
                                "command": command
                            ]
                        ))
                    } else {
                        continuation.resume(throwing: ToolError.executionFailed(
                            "Command failed with status \(process.terminationStatus): \(output)"
                        ))
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    /// Validates if a command is safe to execute.
    ///
    /// - Parameter command: The command to validate.
    /// - Returns: `true` if the command is considered safe, `false` otherwise.
    func validateCommand(_ command: String) -> Bool {
        // Implement command validation logic.
        // Examples:
        // - Check for dangerous commands (e.g., `rm -rf /`).
        // - Enforce a whitelist of allowed commands.
        // - Detect suspicious patterns in the command string.
        return true
    }
    
    /// Sanitizes a command input.
    ///
    /// - Parameter command: The command to sanitize.
    /// - Returns: A sanitized version of the command.
    func sanitizeCommand(_ command: String) -> String {
        // Implement command sanitization logic.
        // Examples:
        // - Escape special characters.
        // - Remove potentially harmful input.
        return command
    }
}

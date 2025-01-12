////
////  ExecuteCommandTool.swift
////  SwiftAgent
////
////  Created by Norikazu Muramoto on 2025/01/11.
////
//
//import Foundation
//import SwiftAgent
//
///// Command execution tool that executes shell commands safely
//public struct ExecuteCommandTool: Tool {
//    public let name = "execute"
//    public let description = """
//        Executes shell commands in a controlled environment.
//        Use this tool when you need to:
//        - Run system commands
//        - Execute shell scripts
//        - Perform system operations
//        
//        Do NOT use this tool for:
//        - Long-running processes
//        - Interactive commands
//        - Commands requiring user input
//        """
//    
//    public let arguments: [ToolArgument] = [
//        .string
//            .name("command")
//            .describe("Shell command to execute")
//            .example("ls -la")
//    ]
//    
//    public let usage = """
//        <execute>
//        <command>npm install express</command>
//        </execute>
//        """
//    
//    public init() {}
//    
//    public func validateParameters(_ parameters: [String: String]) -> Bool {
//        guard let command = parameters["command"] else { return false }
//        return !command.isEmpty
//    }
//    
//    public func execute(parameters: [String: String]) async throws -> ToolResult {
//        guard let command = parameters["command"] else {
//            throw ToolError.missingParameters(["command"])
//        }
//        
//        return try await withCheckedThrowingContinuation { continuation in
//            let process = Process()
//            let pipe = Pipe()
//            
//            process.executableURL = URL(fileURLWithPath: "/bin/bash")
//            process.arguments = ["-c", command]
//            process.standardOutput = pipe
//            process.standardError = pipe
//            
//            // Setup termination handler
//            process.terminationHandler = { process in
//                do {
//                    let data = try pipe.fileHandleForReading.readToEnd() ?? Data()
//                    let output = String(data: data, encoding: .utf8) ?? ""
//                    
//                    if process.terminationStatus == 0 {
//                        continuation.resume(returning: ToolResult(
//                            success: true,
//                            output: output,
//                            metadata: [
//                                "status": "\(process.terminationStatus)",
//                                "command": command
//                            ]
//                        ))
//                    } else {
//                        continuation.resume(throwing: ToolError.executionFailed(
//                            "Command failed with status \(process.terminationStatus): \(output)"
//                        ))
//                    }
//                } catch {
//                    continuation.resume(throwing: error)
//                }
//            }
//            
//            do {
//                try process.run()
//            } catch {
//                continuation.resume(throwing: error)
//            }
//        }
//    }
//}
//
//// MARK: - Safety Extensions
//
//extension ExecuteCommandTool {
//    /// Validates if a command is safe to execute
//    private func validateCommand(_ command: String) -> Bool {
//        // Add command validation logic here
//        // For example:
//        // - Check for dangerous commands
//        // - Validate against allowed command whitelist
//        // - Check for suspicious patterns
//        return true
//    }
//    
//    /// Sanitizes command input
//    private func sanitizeCommand(_ command: String) -> String {
//        // Add command sanitization logic here
//        // For example:
//        // - Remove dangerous characters
//        // - Escape special characters
//        // - Apply security transformations
//        return command
//    }
//}

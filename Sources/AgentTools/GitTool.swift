import Foundation
import SwiftAgent

/// A tool for executing Git commands safely.
///
/// `GitTool` provides a controlled interface for executing Git commands while ensuring
/// basic validation and safety checks.
public struct GitTool: Tool {
    public typealias Input = GitInput
    public typealias Output = GitOutput
    
    public let name = "git_control"
    
    public let description = """
    A tool for executing Git commands safely within a repository.
    
    Use this tool to:
    - Execute basic Git operations
    - Manage repository state
    - Access Git information
    """
    
    public let guide: String? = """
    # git_control Guide
    
    function_name: git_control
    
    ## Description
    `git_control` is a utility for executing Git commands safely within a repository. It provides
    controlled access to Git operations while ensuring basic validation and safety checks.
    
    ### Key Features
    - Execute common Git commands
    - Repository state management
    - Safe command execution
    - Basic validation checks
    
    ### Limitations
    - Complex Git operations requiring interaction are not supported
    - Some Git commands may be restricted for safety
    
    ## Parameters
    ### Required Parameters
    - **command**:
      - **Type**: `String`
      - **Description**: The Git command to execute
      - **Requirements**: Must be a valid Git command
    
    ### Optional Parameters
    - **repository**:
      - **Type**: `String`
      - **Description**: Path to the Git repository
      - **Requirements**: Must be a valid path to a Git repository
    
    - **args**:
      - **Type**: `[String]`
      - **Description**: Additional arguments for the Git command
      - **Requirements**: Must be valid Git command arguments
    
    ## Usage
    ### General Guidelines
    - Ensure the Git command is safe and appropriate
    - Verify repository paths before execution
    - Handle errors appropriately
    - Consider command timeouts for long operations
    
    ### Common Scenarios
    1. **Repository Status**: Use `git status` to check repository state
    2. **Branch Operations**: Create, list, or switch branches
    3. **Commit Operations**: Create commits, view history
    
    ## Multiple Command Operations
    Some Git operations typically require multiple commands to be executed in sequence. Here's how to handle these cases:
    
    ### Commit and Push Changes
    This operation requires two separate tool calls:
    1. First commit the changes
    2. Then push to remote
    
    ```json
    // First call: Commit changes
    {
      "command": "commit",
      "repository": "/path/to/repo",
      "args": ["-m", "Update feature X"]
    }
    
    // Second call: Push changes
    {
      "command": "push",
      "repository": "/path/to/repo",
      "args": ["origin", "main"]
    }
    ```
    
    ### Feature Branch Creation and Switch
    ```json
    // First call: Create new branch
    {
      "command": "branch",
      "repository": "/path/to/repo",
      "args": ["feature/new-feature"]
    }
    
    // Second call: Switch to the new branch
    {
      "command": "checkout",
      "repository": "/path/to/repo",
      "args": ["feature/new-feature"]
    }
    ```
    
    ## Examples
    
    ### Example 1: Check Repository Status
    ```json
    {
      "command": "status",
      "repository": "/path/to/repo"
    }
    ```
    **Expected Output**:
    ```json
    {
      "success": true,
      "output": "On branch main\\nYour branch is up to date with 'origin/main'",
      "metadata": {
        "command": "git status",
        "repository": "/path/to/repo"
      }
    }
    ```
    
    ### Example 2: Create New Branch
    ```json
    {
      "command": "checkout",
      "repository": "/path/to/repo",
      "args": ["-b", "feature/new-branch"]
    }
    ```
    **Expected Output**:
    ```json
    {
      "success": true,
      "output": "Switched to a new branch 'feature/new-branch'",
      "metadata": {
        "command": "git checkout -b feature/new-branch",
        "repository": "/path/to/repo"
      }
    }
    ```
    
    ### Example 3: Invalid Command
    ```json
    {
      "command": "invalid_command",
      "repository": "/path/to/repo"
    }
    ```
    **Expected Output**:
    ```json
    {
      "success": false,
      "output": "git: 'invalid_command' is not a git command",
      "metadata": {
        "error": "Invalid Git command: invalid_command"
      }
    }
    ```
    """
    
    public let parameters: JSONSchema = .object(
        description: "Schema for Git operations",
        properties: [
            "command": .string(description: "The Git command to execute"),
            "repository": .string(description: "Path to the Git repository"),
            "args": .array(
                description: "Additional command arguments",
                items: .string(description: "Command argument")
            )
        ],
        required: ["command"]
    )
    
    private let fileManager: FileManager
    private let gitPath: String
    
    public init(gitPath: String = "/usr/bin/git", fileManager: FileManager = .default) {
        self.gitPath = gitPath
        self.fileManager = fileManager
    }
    
    public func run(_ input: GitInput) async throws -> GitOutput {
        // Validate repository path if provided
        if let repo = input.repository {
            guard fileManager.fileExists(atPath: repo) else {
                return GitOutput(
                    success: false,
                    output: "Repository path does not exist: \(repo)",
                    metadata: [
                        "error": "Invalid repository path: \(repo)"
                    ]
                )
            }
            
            guard isGitRepository(at: repo) else {
                return GitOutput(
                    success: false,
                    output: "Not a Git repository: \(repo)",
                    metadata: [
                        "error": "Not a Git repository: \(repo)"
                    ]
                )
            }
        }
        
        // Validate and sanitize command
        guard isValidGitCommand(input.command) else {
            return GitOutput(
                success: false,
                output: "Invalid Git command: \(input.command)",
                metadata: [
                    "error": "Invalid Git command: \(input.command)"
                ]
            )
        }
        
        // Execute Git command
        return try await executeGitCommand(input)
    }
}

// MARK: - Input/Output Types

public struct GitInput: Codable, Sendable {
    public let command: String
    public let repository: String?
    public let args: [String]
    
    public init(command: String, repository: String? = nil, args: [String] = []) {
        self.command = command
        self.repository = repository
        self.args = args
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        command = try container.decode(String.self, forKey: .command)
        repository = try container.decodeIfPresent(String.self, forKey: .repository)
        
        // Handle various array formats
        if let argsArray = try? container.decode([String].self, forKey: .args) {
            args = argsArray
        } else if let argsString = try? container.decode(String.self, forKey: .args),
                  let data = argsString.data(using: .utf8),
                  let jsonArray = try? JSONDecoder().decode([String].self, from: data) {
            args = jsonArray
        } else {
            args = []  // デフォルトは空の配列
        }
    }
}

public struct GitOutput: Codable, Sendable, CustomStringConvertible {
    public let success: Bool
    public let output: String
    public let metadata: [String: String]
    
    public init(success: Bool, output: String, metadata: [String: String]) {
        self.success = success
        self.output = output
        self.metadata = metadata
    }
    
    public var description: String {
        let status = success ? "Success" : "Failed"
        let metadataString = metadata.isEmpty ? "" : "\nMetadata:\n" + metadata.map { "  \($0.key): \($0.value)" }.joined(separator: "\n")
        
        return """
        Git Command [\(status)]
        Output: \(output)\(metadataString)
        """
    }
}

// MARK: - Private Methods

private extension GitTool {
    func isGitRepository(at path: String) -> Bool {
        let gitPath = (path as NSString).appendingPathComponent(".git")
        return fileManager.fileExists(atPath: gitPath)
    }
    
    func isValidGitCommand(_ command: String) -> Bool {
        // Comprehensive list of allowed Git commands
        let allowedCommands = [
            // Basic commands
            "init", "clone", "add", "status", "commit", "push", "pull",
            
            // Branch operations
            "branch", "checkout", "switch", "merge", "rebase",
            
            // File operations
            "ls-files", "rm", "mv", "restore",
            
            // History and diffs
            "log", "diff", "show", "blame", "grep",
            
            // Remote operations
            "remote", "fetch", "submodule",
            
            // State management
            "reset", "revert", "cherry-pick", "clean",
            
            // Tags
            "tag", "describe",
            
            // Information and help
            "status", "log", "show", "diff", "shortlog",
            
            // Working directory
            "stash", "worktree",
            
            // Configuration
            "config", "var",
            
            // Repository maintenance
            "fsck", "reflog", "gc", "prune",
            
            // Advanced operations
            "bisect", "notes", "replace", "repack",
            
            // Low-level commands
            "cat-file", "count-objects", "rev-parse", "rev-list",
            "for-each-ref", "update-ref", "verify-pack",
            
            // Patching
            "apply", "format-patch", "am", "request-pull",
            
            // Debugging
            "blame", "annotate", "rerere", "verify-commit",
            
            // Hooks
            "pre-commit", "post-commit", "pre-push",
            
            // LFS commands
            "lfs"
        ]
        
        // Special handling for compound commands (e.g., "ls-files", "cat-file")
        let compoundCommands = [
            "ls-files", "cat-file", "for-each-ref", "format-patch",
            "rev-parse", "rev-list", "verify-pack", "pre-commit",
            "post-commit", "pre-push"
        ]
        
        // Direct match
        if allowedCommands.contains(command) {
            return true
        }
        
        // Check for compound commands
        if let _ = compoundCommands.first(where: { command.hasPrefix($0) }) {
            return true
        }
        
        return false
    }
    
    func executeGitCommand(_ input: GitInput) async throws -> GitOutput {
        // 実行するコマンドと引数を準備
        let arguments = [input.command] + input.args
        let commandString = "git " + arguments.joined(separator: " ")
        
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: gitPath)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe
        
        if let repo = input.repository {
            process.currentDirectoryURL = URL(fileURLWithPath: repo)
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { process in
                do {
                    let data = try pipe.fileHandleForReading.readToEnd() ?? Data()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    
                    if process.terminationStatus == 0 {
                        continuation.resume(returning: GitOutput(
                            success: true,
                            output: output,
                            metadata: [
                                "command": commandString,
                                "repository": input.repository ?? "current directory"
                            ]
                        ))
                    } else {
                        continuation.resume(returning: GitOutput(
                            success: false,
                            output: output,
                            metadata: [
                                "error": "Command failed with status: \(process.terminationStatus)",
                                "command": commandString
                            ]
                        ))
                    }
                } catch {
                    continuation.resume(returning: GitOutput(
                        success: false,
                        output: error.localizedDescription,
                        metadata: [
                            "error": "Failed to execute command: \(error.localizedDescription)"
                        ]
                    ))
                }
            }
            
            do {
                try process.run()
            } catch {
                continuation.resume(returning: GitOutput(
                    success: false,
                    output: "Failed to start command: \(error.localizedDescription)",
                    metadata: [
                        "error": "Failed to start command: \(error.localizedDescription)"
                    ]
                ))
            }
        }
    }
}

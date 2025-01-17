//
//  FileSystemTool.swift
//  SwiftAgent
//
//  Created by Norikazu Muramoto on 2025/01/13.
//

import Foundation
import SwiftAgent

/// A tool for performing file system operations safely within a controlled working directory.
///
/// `FileSystemTool` allows controlled access to read, write, and list files or directories
/// while enforcing path safety to prevent access outside the specified working directory.
///
/// ## Features
/// - Read file contents as UTF-8 text
/// - Write text data to files
/// - List directory contents
///
/// ## Limitations
/// - Operates only within the configured working directory
/// - Does not support binary file operations
/// - Does not allow modifications to system files
public struct FileSystemTool: Tool {
    public typealias Input = FileSystemInput
    public typealias Output = FileSystemOutput
    
    public let name = "filesystem"
    
    public let description = """
    A tool for performing file system operations within a controlled working directory.
    """
    
    public let guide: String? = """
    # filesystem Guide
    
    ## Description
    `filesystem` is a utility for performing file system operations in a controlled and safe manner. It ensures that all operations are restricted to the specified working directory and supports the following functionalities:
    - Reading file contents as UTF-8 text.
    - Writing text data to files.
    - Listing directory contents.
    
    ### Key Features
    - Enforces path safety to prevent access outside the working directory.
    - Operates on files and directories within the defined workspace.
    - Prevents access to system-critical files.
    
    ### Limitations
    - Binary file operations are not supported.
    - Access outside the working directory is disallowed.
    - Cannot modify system files.
    
    ## Parameters
    ### Required Parameters
    - **operation**:
      - **Type**: `String`
      - **Description**: The type of operation to perform. Valid values are:
        - `"read"`: Read the contents of a file.
        - `"write"`: Write text data to a file.
        - `"list"`: List the contents of a directory.
    - **path**:
      - **Type**: `String`
      - **Description**: The relative path to the target file or directory.
      - **Requirements**: Must be within the working directory.
    
    ### Optional Parameters
    - **content** (only for `write` operation):
      - **Type**: `String`
      - **Description**: The text content to write to the file.
    
    ## Usage
    ### General Guidelines
    - Always provide a valid relative path for the `path` parameter.
    - Ensure that the `content` parameter is provided when performing a `write` operation.
    - Use UTF-8 encoded text for file contents.
    - Avoid attempting operations on paths outside the working directory.
    
    ### Common Scenarios
    1. **Reading a File**: Ensure the target file exists and contains UTF-8 encoded text.
    2. **Writing to a File**: The file will be created if it does not exist, and its content will be overwritten.
    3. **Listing Directory Contents**: Only files and subdirectories within the target directory will be listed.
    
    ## Examples
    
    ### Example 1: Read a File
    ```json
    {
      "operation": "read",
      "path": "documents/report.txt"
    }
    ```
    **Expected Output**:
    ```json
    {
      "success": true,
      "content": "This is the content of the file.",
      "metadata": {
        "operation": "read",
        "path": "documents/report.txt",
        "size": "28"
      }
    }
    ```
    
    ### Example 2: Write to a File
    ```json
    {
      "operation": "write",
      "path": "notes/todo.txt",
      "content": "Buy groceries\nCall the doctor"
    }
    ```
    **Expected Output**:
    ```json
    {
      "success": true,
      "content": "File written successfully",
      "metadata": {
        "operation": "write",
        "path": "notes/todo.txt",
        "size": "32"
      }
    }
    ```
    
    ### Example 3: List Directory Contents
    ```json
    {
      "operation": "list",
      "path": "projects/"
    }
    ```
    **Expected Output**:
    ```json
    {
      "success": true,
      "content": "project1/\nproject2/\nREADME.md",
      "metadata": {
        "operation": "list",
        "path": "projects/",
        "count": "3"
      }
    }
    ```
    
    ### Example 4: Attempt to Access an Unsafe Path
    ```json
    {
      "operation": "read",
      "path": "../../etc/passwd"
    }
    ```
    **Expected Output**:
    ```json
    {
      "success": false,
      "content": "Path is not within working directory: ../../etc/passwd",
      "metadata": {
        "operation": "read",
        "error": "Path is not within working directory: ../../etc/passwd"
      }
    }
    ```
    """
    
    public let parameters: JSONSchema = .object(
        description: "Schema for file system operations",
        properties: [
            "operation": .enum(
                description: "The operation to perform (read/write/list)",
                values: [.string("read"), .string("write"), .string("list")]
            ),
            "path": .string(description: "Path to the file or directory"),
            "content": .string(description: "Content to write (for write operation)")
        ],
        required: ["operation", "path"]
    )
    
    private let workingDirectory: String
    private let fsActor: FileSystemActor
    
    public init(workingDirectory: String) {
        self.workingDirectory = workingDirectory
        self.fsActor = FileSystemActor()
    }
    
    public func run(_ input: FileSystemInput) async throws -> FileSystemOutput {
        let normalizedPath = normalizePath(input.path)
        guard isPathSafe(normalizedPath) else {
            return FileSystemOutput(
                success: false,
                content: "Path is not within working directory: \(input.path)",
                metadata: [
                    "operation": input.operation.rawValue,
                    "error": "Path is not within working directory: \(input.path)"
                ]
            )
        }
        
        switch input.operation {
        case .read:
            return try await readFile(at: normalizedPath)
        case .write:
            guard let content = input.content else {
                return FileSystemOutput(
                    success: false,
                    content: "Missing content for write operation",
                    metadata: [
                        "operation": input.operation.rawValue,
                        "error": "Missing content for write operation"
                    ]
                )
            }
            return try await writeFile(content: content, to: normalizedPath)
        case .list:
            return try await listDirectory(at: normalizedPath)
        }
    }
}


// MARK: - Input/Output Types

/// The input structure for file system operations.
public struct FileSystemInput: Codable, Sendable {
    /// The type of file system operation.
    public enum Operation: String, Codable, Sendable {
        case read
        case write
        case list
    }
    
    /// The operation to perform (e.g., read, write, or list).
    public let operation: Operation
    
    /// The path to the file or directory.
    public let path: String
    
    /// The content to write (used only for `write` operations).
    public let content: String?
    
    /// Creates a new instance of `FileSystemInput`.
    ///
    /// - Parameters:
    ///   - operation: The operation to perform.
    ///   - path: The target file or directory path.
    ///   - content: The content to write (optional, for `write` operations only).
    public init(operation: Operation, path: String, content: String? = nil) {
        self.operation = operation
        self.path = path
        self.content = content
    }
}

/// The output structure for file system operations.
public struct FileSystemOutput: Codable, Sendable, CustomStringConvertible {
    /// Whether the operation was successful.
    public let success: Bool
    
    /// The content produced by the operation (e.g., file contents or directory listing).
    public let content: String
    
    /// Additional metadata about the operation.
    public let metadata: [String: String]
    
    /// Creates a new instance of `FileSystemOutput`.
    ///
    /// - Parameters:
    ///   - success: Indicates if the operation succeeded.
    ///   - content: The content resulting from the operation.
    ///   - metadata: Additional information about the operation.
    public init(success: Bool, content: String, metadata: [String: String]) {
        self.success = success
        self.content = content
        self.metadata = metadata
    }
    
    public var description: String {
        let status = success ? "Success" : "Failed"
        let metadataString = metadata.isEmpty ? "" : "\nMetadata:\n" + metadata.map { "  \($0.key): \($0.value)" }.joined(separator: "\n")
        
        return """
        FileSystem Operation [\(status)]
        Content: \(content)\(metadataString)
        """
    }
}

// MARK: - Private File Operations

private extension FileSystemTool {
    func readFile(at path: String) async throws -> FileSystemOutput {
        guard await fsActor.fileExists(atPath: path) else {
            return FileSystemOutput(
                success: false,
                content: "File not found: \(path)",
                metadata: [
                    "operation": "read",
                    "error": "File not found: \(path)"
                ]
            )
        }
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            guard let content = String(data: data, encoding: .utf8) else {
                return FileSystemOutput(
                    success: false,
                    content: "Could not read file as UTF-8 text",
                    metadata: [
                        "operation": "read",
                        "error": "Could not read file as UTF-8 text"
                    ]
                )
            }
            
            return FileSystemOutput(
                success: true,
                content: content,
                metadata: [
                    "operation": "read",
                    "path": path,
                    "size": "\(data.count)"
                ]
            )
        } catch {
            return FileSystemOutput(
                success: false,
                content: "Failed to read file: \(error.localizedDescription)",
                metadata: [
                    "operation": "read",
                    "error": "Failed to read file: \(error.localizedDescription)"
                ]
            )
        }
    }
    
    func writeFile(content: String, to path: String) async throws -> FileSystemOutput {
        do {
            try content.write(toFile: path, atomically: true, encoding: .utf8)
            return FileSystemOutput(
                success: true,
                content: "File written successfully",
                metadata: [
                    "operation": "write",
                    "path": path,
                    "size": "\(content.utf8.count)"
                ]
            )
        } catch {
            return FileSystemOutput(
                success: false,
                content: "Failed to write file: \(error.localizedDescription)",
                metadata: [
                    "operation": "write",
                    "error": "Failed to write file: \(error.localizedDescription)"
                ]
            )
        }
    }
    
    func listDirectory(at path: String) async throws -> FileSystemOutput {
        do {
            let contents = try await fsActor.contentsOfDirectory(atPath: path)
            let formattedContents = try await withThrowingTaskGroup(of: String.self) { group in
                
                let localPath = path
                let localActor = fsActor
                
                for item in contents {
                    group.addTask {
                        let itemPath = (localPath as NSString).appendingPathComponent(item)
                        let isDirectory = await localActor.isDirectory(atPath: itemPath)
                        return isDirectory ? "\(item)/" : item
                    }
                }
                
                return try await group.reduce(into: []) { $0.append($1) }.sorted()
            }
            
            return FileSystemOutput(
                success: true,
                content: formattedContents.joined(separator: "\n"),
                metadata: [
                    "operation": "list",
                    "path": path,
                    "count": "\(contents.count)"
                ]
            )
        } catch {
            return FileSystemOutput(
                success: false,
                content: "Failed to list directory: \(error.localizedDescription)",
                metadata: [
                    "operation": "list",
                    "error": "Failed to list directory: \(error.localizedDescription)"
                ]
            )
        }
    }
}

// MARK: - Path Safety

private extension FileSystemTool {
    func normalizePath(_ path: String) -> String {
        let fullPath = (workingDirectory as NSString).appendingPathComponent(path)
        return (fullPath as NSString).standardizingPath
    }
    
    func isPathSafe(_ path: String) -> Bool {
        let normalizedWorkingDir = (workingDirectory as NSString).standardizingPath
        return path.hasPrefix(normalizedWorkingDir)
    }
}

/// Actor for handling file system operations in a thread-safe manner.
private actor FileSystemActor {
    private let fileManager: FileManager
    
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }
    
    func fileExists(atPath path: String) -> Bool {
        fileManager.fileExists(atPath: path)
    }
    
    func contentsOfDirectory(atPath path: String) throws -> [String] {
        try fileManager.contentsOfDirectory(atPath: path)
    }
    
    func isDirectory(atPath path: String) -> Bool {
        var isDirectory: ObjCBool = false
        fileManager.fileExists(atPath: path, isDirectory: &isDirectory)
        return isDirectory.boolValue
    }
}

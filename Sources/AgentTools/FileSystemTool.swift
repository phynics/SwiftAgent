//
//  FileSystemTool.swift
//  SwiftAgent
//
//  Created by Norikazu Muramoto on 2025/01/13.
//

import Foundation
import SwiftAgent

/// Tool for performing file system operations safely
public struct FileSystemTool: Tool {
    public typealias Input = FileSystemInput
    public typealias Output = FileSystemOutput
    
    public let name = "filesystem"
    public let description = """
    Performs file system operations within a controlled working directory.
    
    Use this tool when you need to:
    - Read contents of existing files
    - Write data to files
    - List contents of directories
    
    Do NOT use this tool for:
    - Operations outside working directory
    - System file modifications
    - Binary file operations
    """
    
    public let usage: String? = """
    Example:
    Input: {
        "operation": "read",
        "path": "src/index.js"
    }
    """
    
    private let workingDirectory: String
    private let fsActor: FileSystemActor
    
    public init(workingDirectory: String) {
        self.workingDirectory = workingDirectory
        self.fsActor = FileSystemActor()
    }
    
    public func call(_ input: FileSystemInput) async throws -> FileSystemOutput {
        let normalizedPath = normalizePath(input.path)
        guard isPathSafe(normalizedPath) else {
            throw ToolError.invalidParameters("Path is not within working directory: \(input.path)")
        }
        
        switch input.operation {
        case .read:
            return try await readFile(at: normalizedPath)
        case .write:
            guard let content = input.content else {
                throw ToolError.missingParameters(["content"])
            }
            return try await writeFile(content: content, to: normalizedPath)
        case .list:
            return try await listDirectory(at: normalizedPath)
        }
    }
}

// MARK: - Input/Output Types

public struct FileSystemInput: Codable, Sendable {
    public enum Operation: String, Codable, Sendable {
        case read
        case write
        case list
    }
    
    let operation: Operation
    let path: String
    let content: String?
    
    public init(operation: Operation, path: String, content: String? = nil) {
        self.operation = operation
        self.path = path
        self.content = content
    }
}

public struct FileSystemOutput: Codable, Sendable {
    public let success: Bool
    public let content: String
    public let metadata: [String: String]
    
    public init(success: Bool, content: String, metadata: [String: String]) {
        self.success = success
        self.content = content
        self.metadata = metadata
    }
}

// MARK: - Private File Operations

private extension FileSystemTool {
    func readFile(at path: String) async throws -> FileSystemOutput {
        guard await fsActor.fileExists(atPath: path) else {
            throw ToolError.executionFailed("File not found: \(path)")
        }
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            guard let content = String(data: data, encoding: .utf8) else {
                throw ToolError.executionFailed("Could not read file as UTF-8 text")
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
            throw ToolError.executionFailed("Failed to read file: \(error.localizedDescription)")
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
            throw ToolError.executionFailed("Failed to write file: \(error.localizedDescription)")
        }
    }
    
    func listDirectory(at path: String) async throws -> FileSystemOutput {
        do {
            let contents = try await fsActor.contentsOfDirectory(atPath: path)
            let formattedContents = try await withThrowingTaskGroup(of: String.self) { group in

                let localPath = path
                let localActor = fsActor
                
                for item in contents {
                    group.addTask { @Sendable in
                        let itemPath = (localPath as NSString).appendingPathComponent(item)
                        let isDirectory = await localActor.isDirectory(atPath: itemPath)
                        return isDirectory ? "\(item)/" : item
                    }
                }
                
                var results: [String] = []
                for try await result in group {
                    results.append(result)
                }
                return results.sorted()
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
            throw ToolError.executionFailed("Failed to list directory: \(error.localizedDescription)")
        }
    }
}

// MARK: - Path Safety

private extension FileSystemTool {
    func normalizePath(_ path: String) -> String {
        let fullPath = (workingDirectory as NSString)
            .appendingPathComponent(path)
        return (fullPath as NSString).standardizingPath
    }
    
    func isPathSafe(_ path: String) -> Bool {
        let normalizedWorkingDir = (workingDirectory as NSString).standardizingPath
        return path.hasPrefix(normalizedWorkingDir)
    }
}

/// Actor for handling file system operations in a thread-safe manner
private actor FileSystemActor {
    private let fileManager: FileManager
    
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }
    
    /// Checks if a file exists at the given path
    func fileExists(atPath path: String) -> Bool {
        fileManager.fileExists(atPath: path)
    }
    
    /// Gets the contents of a directory at the given path
    func contentsOfDirectory(atPath path: String) throws -> [String] {
        try fileManager.contentsOfDirectory(atPath: path)
    }
    
    /// Checks if a path points to a directory
    func isDirectory(atPath path: String) -> Bool {
        var isDirectory: ObjCBool = false
        fileManager.fileExists(atPath: path, isDirectory: &isDirectory)
        return isDirectory.boolValue
    }
}

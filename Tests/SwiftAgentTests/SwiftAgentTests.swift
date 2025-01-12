import Testing
import Foundation
import SwiftAgent
@testable import AgentTools

@Test("FileSystemTool should read file contents correctly")
func testFileSystemToolRead() async throws {
    // Setup temporary directory
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir,
                                            withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }
    
    // Create test file
    let testContent = "Hello, World!"
    let testFile = tempDir.appendingPathComponent("test.txt")
    try testContent.write(to: testFile, atomically: true, encoding: .utf8)
    
    // Initialize tool
    let tool = FileSystemTool(workingDirectory: tempDir.path)
    
    // Test read operation
    let input = FileSystemInput(
        operation: .read,
        path: "test.txt"
    )
    
    let output = try await tool.call(input)
    #expect(output.success)
    #expect(output.content == testContent)
    #expect(output.metadata["operation"] == "read")
    #expect(Int(output.metadata["size"] ?? "") == testContent.utf8.count)
}

@Test("FileSystemTool should write file contents correctly")
func testFileSystemToolWrite() async throws {
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir,
                                            withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }
    
    let tool = FileSystemTool(workingDirectory: tempDir.path)
    let testContent = "New content"
    
    // Test write operation
    let writeInput = FileSystemInput(
        operation: .write,
        path: "newfile.txt",
        content: testContent
    )
    
    let writeOutput = try await tool.call(writeInput)
    #expect(writeOutput.success)
    #expect(writeOutput.metadata["operation"] == "write")
    
    // Verify written content
    let filePath = (tempDir.path as NSString)
        .appendingPathComponent("newfile.txt")
    let writtenContent = try String(contentsOfFile: filePath, encoding: .utf8)
    #expect(writtenContent == testContent)
}

@Test("FileSystemTool should list directory contents correctly")
func testFileSystemToolList() async throws {
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir,
                                            withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }
    
    // Create test files and directory
    try "File1".write(to: tempDir.appendingPathComponent("file1.txt"),
                      atomically: true, encoding: .utf8)
    try "File2".write(to: tempDir.appendingPathComponent("file2.txt"),
                      atomically: true, encoding: .utf8)
    try FileManager.default.createDirectory(
        at: tempDir.appendingPathComponent("subdir"),
        withIntermediateDirectories: false
    )
    
    let tool = FileSystemTool(workingDirectory: tempDir.path)
    
    // Test list operation
    let listInput = FileSystemInput(
        operation: .list,
        path: "."
    )
    
    let output = try await tool.call(listInput)
    #expect(output.success)
    #expect(output.content.contains("file1.txt"))
    #expect(output.content.contains("file2.txt"))
    #expect(output.content.contains("subdir/"))
    #expect(output.metadata["operation"] == "list")
    #expect(output.metadata["count"] == "3")
}

import Testing
import Foundation
import SwiftAgent
@testable import AgentTools


struct TestTool: Tool {
    let name = "test"
    let description = "Test tool"
    let parameters = JSONSchema.object(properties: [:])
    let guide: String? = nil
    
    struct Input: Codable, Sendable {
        let value: String
    }
    
    struct Output: Codable, CustomStringConvertible, Sendable {
        let result: String
        
        var description: String {
            "Output: \(result)"
        }
    }
    
    func run(_ input: Input) async throws -> Output {
        Output(result: "Processed: \(input.value)")
    }
}

@Test("call with encodable arguments")
func testCallWithEncodableArguments() async throws {
    let tool = TestTool()
    let input = TestTool.Input(value: "test input")
    
    let result = try await tool.call(input)
    #expect(result == "Output: Processed: test input")
}

@Test("call with JSON data")
func testCallWithJSONData() async throws {
    let tool = TestTool()
    let jsonString = """
    {
        "value": "test input"
    }
    """
    let jsonData = jsonString.data(using: .utf8)!
    
    let result = try await tool.call(data: jsonData)
    #expect(result == "Output: Processed: test input")
}


@Test("call error handling")
func testCallErrorHandling() async throws {
    struct ErrorTool: Tool {
        let name = "error"
        let description = "Error tool"
        let parameters = JSONSchema.object(properties: [:])
        let guide: String? = nil
        
        struct Input: Codable, Sendable {
            let value: String
        }
        
        struct Output: Codable, CustomStringConvertible, Sendable {
            var description: String { "never called" }
        }
        
        func run(_ input: Input) async throws -> Output {
            struct TestError: Error {
                let message: String
            }
            throw TestError(message: "test error")
        }
    }
    
    let tool = ErrorTool()
    let input = ErrorTool.Input(value: "test")
    
    let result = try await tool.call(input)
    #expect(result.contains("[error] has Error:"))
    #expect(result.contains("test error"))
}

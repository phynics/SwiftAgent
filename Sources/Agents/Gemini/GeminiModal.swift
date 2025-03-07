import Foundation
import SwiftAgent
import AgentTools
@preconcurrency import GoogleGenerativeAI

/// A concrete implementation of the Model protocol using Google's Gemini API.
public struct GeminiModel<Output: Sendable>: SwiftAgent.Model {
    
    public typealias Input = [GoogleGenerativeAI.ModelContent]
    
    /// The underlying Gemini model instance
    private let model: GoogleGenerativeAI.GenerativeModel
    
    /// An array of tools available to the model
    public var tools: [any SwiftAgent.Tool]
    
    /// The system prompt that provides initial context
    public var systemPrompt: String
    
    /// Response parser for converting response to Output type
    private let responseParser: (String) throws -> Output
    
    /// Creates a new instance of GeminiModel for text output
    public init(
        modelName: String = "gemini-2.0-pro-exp-02-05",
        temperature: Float = 0.7,
        tools: [any SwiftAgent.Tool] = [],
        systemPrompt: ([any SwiftAgent.Tool]) -> String
    ) where Output == String {
        guard let apiKey = ProcessInfo.processInfo.environment["GOOGLE_GENAI_API_KEY"] else {
            fatalError("Google API Key is not set in environment variables.")
        }

        let generationConfig = GoogleGenerativeAI.GenerationConfig(
            temperature: temperature,
            topP: 0.95,
            topK: 40,
            maxOutputTokens: 4096
        )
        
        self.tools = tools
        self.systemPrompt = systemPrompt(tools)
        
        // Convert SwiftAgent tools to GoogleGenerativeAI tools
        let geminiTools: [GoogleGenerativeAI.Tool]?
        if tools.isEmpty {
            geminiTools = nil
        } else {
            do {
                let functionDeclarations = try tools.map { tool in
                    try FunctionDeclarationConverter.convert(from: tool)
                }
                geminiTools = [GoogleGenerativeAI.Tool(functionDeclarations: functionDeclarations)]
            } catch {
                print("Warning: Failed to convert tools: \(error)")
                geminiTools = nil
            }
        }
        
        self.model = GoogleGenerativeAI.GenerativeModel(
            name: modelName,
            apiKey: apiKey,
            generationConfig: generationConfig,
            tools: geminiTools,
            systemInstruction: ModelContent(role: "system", parts: [.text(self.systemPrompt)])
        )
        
        self.responseParser = { $0 }
    }
    
    /// Creates a new instance of GeminiModel with a Codable output type
    public init(
        modelName: String = "gemini-2.0-pro-exp-02-05",
        temperature: Float = 0.7,
        schema: JSONSchema,
        tools: [any SwiftAgent.Tool] = [],
        systemPrompt: ([any SwiftAgent.Tool]) -> String
    ) where Output: Codable {
        guard let apiKey = ProcessInfo.processInfo.environment["GOOGLE_GENAI_API_KEY"] else {
            fatalError("Google API Key is not set in environment variables.")
        }
        
        // Convert JSONSchema to GoogleGenerativeAI Schema
        let responseSchema: Schema?
        do {
            responseSchema = try SchemaConverter.convert(schema)
        } catch {
            print("Warning: Failed to convert response schema: \(error)")
            responseSchema = nil
        }
        
        let generationConfig = GoogleGenerativeAI.GenerationConfig(
            temperature: temperature,
            topP: 0.95,
            topK: 40,
            maxOutputTokens: 4096,
            responseMIMEType: "application/json",
            responseSchema: responseSchema
        )
        
        self.tools = tools
        self.systemPrompt = systemPrompt(tools)
        
        // Convert SwiftAgent tools to GoogleGenerativeAI tools
        let geminiTools: [GoogleGenerativeAI.Tool]?
        if tools.isEmpty {
            geminiTools = nil
        } else {
            do {
                let functionDeclarations = try tools.map { tool in
                    try FunctionDeclarationConverter.convert(from: tool)
                }
                geminiTools = [GoogleGenerativeAI.Tool(functionDeclarations: functionDeclarations)]
            } catch {
                print("Warning: Failed to convert tools: \(error)")
                geminiTools = nil
            }
        }
        
        self.model = GoogleGenerativeAI.GenerativeModel(
            name: modelName,
            apiKey: apiKey,
            generationConfig: generationConfig,
            tools: geminiTools,
            systemInstruction: ModelContent(role: "system", parts: [.text(self.systemPrompt)])
        )
        
        // Setup JSON response parser
        self.responseParser = { jsonString in
            guard let data = jsonString.data(using: .utf8) else {
                throw GeminiModelError.invalidResponse
            }
            do {
                return try JSONDecoder().decode(Output.self, from: data)
            } catch {
                throw GeminiModelError.jsonParsingError(error)
            }
        }
    }
    
    public func run(_ input: [GoogleGenerativeAI.ModelContent]) async throws -> Output {
        var completeResponse = ""
        
        let response = try await model.generateContent(input)
        if let promptFeedback = response.promptFeedback,
           let blockReason = promptFeedback.blockReason {
            throw GeminiModelError.promptBlocked(reason: blockReason.rawValue)
        }
        
        if let text = response.text {
            completeResponse = text
        }
        
        // Handle function calls if present
        for functionCall in response.functionCalls {
            if let tool = tools.first(where: { $0.name == functionCall.name }) {
                let result = try await tool.call(functionCall.args)
                completeResponse += "\nTool result: \(result)"
            }
        }
        
        return try responseParser(completeResponse)
    }
}

/// Errors specific to GeminiModel
public enum GeminiModelError: Error {
    case invalidResponse
    case promptBlocked(reason: String)
    case toolError(String)
    case jsonParsingError(Error)
    case schemaConversionError(Error)
}

/// A step that stores messages in the conversation history
public struct GeminiMessageStore: Step {
    public typealias Input = String
    public typealias Output = String
    
    @Relay var messages: [GoogleGenerativeAI.ModelContent]
    
    public init(messages: Relay<[GoogleGenerativeAI.ModelContent]>) {
        self._messages = messages
    }
    
    public func run(_ input: Input) async throws -> Output {
        messages.append(GoogleGenerativeAI.ModelContent(role: "assistant", parts: [.text(input)]))
        return input
    }
}

/// A step that transforms user messages for the model
public struct GeminiMessageTransform: Step {
    public typealias Input = String
    public typealias Output = [GoogleGenerativeAI.ModelContent]
    
    @Relay var messages: [GoogleGenerativeAI.ModelContent]
    
    public init(messages: Relay<[GoogleGenerativeAI.ModelContent]>) {
        self._messages = messages
    }
    
    public func run(_ input: Input) async throws -> Output {
        messages.append(GoogleGenerativeAI.ModelContent(role: "user", parts: [.text(input)]))
        return messages
    }
}

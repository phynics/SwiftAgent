//
//  OllamaModel.swift
//  SwiftAgent
//
//  Created by Norikazu Muramoto on 2025/01/11.
//

import Foundation
import SwiftAgent
import AgentTools
import OllamaKit

/// OllamaKit based implementation of Model
public struct OllamaModel: Model {
    
    public typealias Input = [OKChatRequestData.Message]

    public typealias Output = String

  
    public var tools: [any Tool] = [
        FileSystemTool(workingDirectory: FileManager.default.currentDirectoryPath),
        ExecuteCommandTool()
    ]
    
    public var systemPrompt: String
    
    public init(_ systemPrompt: ([any Tool]) -> String) {
        self.systemPrompt = systemPrompt(tools)
    }
    
    public func run(_ input: [OKChatRequestData.Message]) async throws -> String {
        let ollama = OllamaKit()
        let okTools = tools.map { tool -> OKTool in
                .function(
                    OKFunction(
                        name: tool.name,
                        description: tool.description,
                        parameters: tool.parameters
                    )
                )
        }
        let messages: [OKChatRequestData.Message] = [.system(systemPrompt)] + input
        let stream: AsyncThrowingStream<OKChatResponse, Error> = ollama
            .chat(
                data: .init(
                    model: "llama3.2:latest",
                    messages: messages,
                    tools: okTools
                )
            )
        var output = ""
        for try await response in stream {
            // メッセージの処理
            if let message = response.message {
                // コンテンツの追加
                output += message.content
                
                // ツール呼び出しの処理
                if let toolCalls = message.toolCalls {
                    for toolCall in toolCalls {
                        if let function = toolCall.function,
                           let name = function.name,
                           let arguments = function.arguments,
                           let tool = tools.first(where: { $0.name == name }) {
                            
                            if let fileSystemTool = tool as? FileSystemTool {
                                // JSONデータの準備
                                let jsonData = try JSONEncoder().encode(arguments)
                                
                                // ツールの入力を準備
                                let input = try JSONDecoder().decode(
                                    FileSystemInput.self,
                                    from: jsonData
                                )
                                
                                // ツールを実行
                                let result = try await fileSystemTool.call(input)
                                
                                // 結果をモデルに返す
                                output += "\n  Tool result: \(result.content)"
                            }
                        }
                    }
                }
            }
            
            if response.done {
                break
            }
        }
        
        return output
    }
}

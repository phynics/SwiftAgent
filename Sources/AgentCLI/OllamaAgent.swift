//
//  OllamaAgent.swift
//  SwiftAgent
//
//  Created by Assistant on 2025/01/11.
//

import Foundation
import SwiftAgent

/// Enhanced agent implementation using Ollama model
public struct OllamaAgent: Agent {
    // 具体的な Input/Output 型を定義
    public typealias Input = String
    
    public typealias Output = String
    
    public init() {}
    
    public var body: some Step<Input, Output> {
        OllamaModel("ユーザーの指示に従って操作を行ってください。").log()
    }
}

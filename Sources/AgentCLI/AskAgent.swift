//
//  AskAgent.swift
//  SwiftAgent
//
//  Created by Norikazu Muramoto on 2025/01/22.
//

import Foundation
import SwiftAgent
import Agents
import LLMChatOpenAI

public struct AskAgent: Agent {
    
    public var body: some Step<String, String> {
        Loop(max: 3) { _ in
            GeminiAgent()
                .onOutput { message in
                    print(message)
                }
        } until: {
            Transform<String, Bool> { message in
                return true
            }
        }
    }
}

//
//  MainAgent.swift
//  SwiftAgent
//
//  Created by Norikazu Muramoto on 2025/01/13.
//

import Foundation
import SwiftAgent
import Agents
import LLMChatOpenAI

public struct MainAgent: Agent {

    public var body: some Step<String, String> {
        OpenAIAgent()
    }
}

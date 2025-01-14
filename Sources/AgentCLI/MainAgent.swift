//
//  MainAgent.swift
//  SwiftAgent
//
//  Created by Norikazu Muramoto on 2025/01/13.
//

import Foundation
import SwiftAgent

public struct MainAgent: Agent {

    public var body: some Step<String, String> {
        Loop(max: 2) { input in
            OpenAIAgent()
        } until: { output in
            return !output.contains("error")
        }
    }
}

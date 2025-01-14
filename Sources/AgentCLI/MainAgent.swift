//
//  MainAgent.swift
//  SwiftAgent
//
//  Created by Norikazu Muramoto on 2025/01/13.
//

import Foundation
import SwiftAgent
import Agents

public struct MainAgent: Agent {

    public var body: some Step<String, String> {
        Loop(max: 2) { input in
            OllamaAgent()
        } until: { output in
            return !output.contains("error")
        }
    }
}

//
//  AgentActor.swift
//  SynapseKit
//
//  Created by Norikazu Muramoto on 2024/10/18.
//

import Foundation
import Distributed
import DistributedCluster
import OllamaKit
import SwiftAgent

public enum AgentActorError: Error {
    case invalidInstruction
}

public distributed actor RemoteInput {
    
    public typealias ActorSystem = ClusterSystem
        
    public init(actorSystem: ActorSystem) {
        self.actorSystem = actorSystem
    }
    
    /// Receive and store user input
    public distributed func sendMessage(_ input: String) async -> String {
        return input
    }
    
    public distributed func shatdown() throws {
        try self.actorSystem.shutdown()
    }
}

extension DistributedReception.Key {
    public static func agent(id: String) -> DistributedReception.Key<RemoteInput> {
        .init(id: id)
    }
}

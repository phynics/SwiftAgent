// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftAgent",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(
            name: "SwiftAgent",
            targets: ["SwiftAgent"]),
        .library(
            name: "Agents",
            targets: ["Agents"]),
        .library(
            name: "AgentTools",
            targets: ["AgentTools"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", branch: "main"),
        .package(url: "https://github.com/kevinhermawan/swift-json-schema.git", branch: "main"),
        .package(url: "https://github.com/kevinhermawan/swift-llm-chat-openai.git", branch: "main"),
        .package(url: "https://github.com/1amageek/OllamaKit.git", branch: "main"),
        .package(url: "https://github.com/apple/swift-distributed-actors.git", branch: "main"),
        .package(url: "https://github.com/jamesrochabrun/SwiftAnthropic.git", branch: "main")
    ],
    targets: [
        .target(
            name: "SwiftAgent",
            dependencies: [
                .product(name: "JSONSchema", package: "swift-json-schema")
            ]
        ),
        .target(
            name: "Agents",
            dependencies: [
                "SwiftAgent",
                "AgentTools",
                "SwiftAnthropic",
                "OllamaKit",
                .product(name: "LLMChatOpenAI", package: "swift-llm-chat-openai"),
            ]
        ),
        .target(
            name: "AgentTools",
            dependencies: ["SwiftAgent"]
        ),
        .target(
            name: "AgentActor",
            dependencies: [
                "SwiftAgent",
                .product(name: "DistributedCluster", package: "swift-distributed-actors")
            ]
        ),
        .executableTarget(
            name: "AgentCLI",
            dependencies: [
                "SwiftAgent",
                "AgentTools",
                "Agents",
                "SwiftAnthropic",
                "OllamaKit",
                .product(name: "LLMChatOpenAI", package: "swift-llm-chat-openai"),
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .testTarget(
            name: "SwiftAgentTests",
            dependencies: ["SwiftAgent", "AgentTools"]
        ),
    ]
)

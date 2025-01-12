# SwiftAgent

SwiftAgent is a powerful Swift framework that enables declarative development of AI agents in a SwiftUI-like syntax. It provides a clean, elegant way to compose complex agent workflows while maintaining the type safety and expressiveness of Swift.

## Features

- 🎯 **Declarative Syntax**: Build agents using familiar SwiftUI-like syntax
- 🔄 **Composable Steps**: Chain multiple steps together seamlessly
- 🛠️ **Type-Safe Tools**: Define and use tools with compile-time type checking
- 🤖 **LLM Integration**: Easy integration with language models
- 📦 **Modular Design**: Create reusable agent components
- 🔄 **Async/Await Support**: Built for modern Swift concurrency
- 🎭 **Protocol-Based**: Flexible and extensible architecture

## Requirements

- Swift 6.0+
- iOS 18.0+ / macOS 15.0+

## Installation

### Swift Package Manager

Add SwiftAgent to your Swift package dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/1amageek/SwiftAgent.git", branch: "main")
]
```

## Basic Concepts

### Steps

Steps are the fundamental building blocks in SwiftAgent. Each step processes an input and produces an output:

```swift
public protocol Step<Input, Output> {
    associatedtype Input: Codable & Sendable
    associatedtype Output: Codable & Sendable
    
    func run(_ input: Input) async throws -> Output
}
```

### Tools

Tools represent capabilities that can be used by agents:

```swift
public protocol Tool {
    associatedtype Input: Codable & Sendable
    associatedtype Output: Codable & Sendable
    
    var name: String { get }
    var description: String { get }
    
    func call(_ input: Input) async throws -> Output
}
```

### Agents

Agents combine steps and tools into cohesive workflows:

```swift
struct SearchAgent: Agent {
    var body: some Step<String, String> {
        ModelStep()
        SearchTool()
        SummarizationStep()
    }
}
```

## Usage Examples

### Creating a Simple Agent

```swift
struct WeatherAgent: Agent {
    var body: some Step<String, WeatherResponse> {
        // Parse user query
        QueryParsingStep()
        
        // Fetch weather data
        WeatherTool()
        
        // Format response
        ResponseFormattingStep()
    }
}
```

### Conditional Steps

```swift
struct SmartAgent: Agent {
    var body: some Step<Query, Response> {
        if condition {
            StepA()
        } else {
            StepB()
        }
    }
}
```

### Loops

```swift
struct IterativeAgent: Agent {
    var body: some Step<Data, Result> {
        Loop(max: 5) {
            ProcessingStep()
        } until: { result in
            result.isComplete
        }
    }
}
```

## Packages

SwiftAgent consists of several packages:

- **SwiftAgent**: Core framework with base protocols and components
- **AgentTools**: Collection of ready-to-use tools
- **AgentCLI**: Command-line interface for agent execution

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

SwiftAgent is available under the MIT license.

## Author

@1amageek

## Acknowledgments

SwiftAgent is inspired by SwiftUI's declarative syntax and the concepts outlined in various agent architectures. Special thanks to the Swift and AI communities for their ongoing contributions to these fields.

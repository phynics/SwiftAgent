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
- 📊 **State Management**: Powerful state management with Memory and Relay
- 🔍 **Monitoring**: Built-in monitoring capabilities for debugging and logging

## Requirements

- Swift 6.0+
- iOS 18.0+ / macOS 15.0+
- Ollama installed (for Ollama integration)
- Anthropic API key (for Claude integration)
- OpenAI API key (for OpenAI integration)

## Development Setup

### 1. Install Ollama

Install Ollama following the official instructions at [Ollama Installation Guide](https://ollama.ai/download).

### 2. Configure API Keys

Add the following environment variables to your Xcode scheme:

1. Open your Xcode project
2. Go to Edit Scheme (⌘ + <)
3. Select "Run" from the left sidebar
4. Go to the "Arguments" tab
5. Under "Environment Variables", add:
   - `ANTHROPIC_API_KEY`: Your Anthropic API key
   - `OPENAI_API_KEY`: Your OpenAI API key

You can also add these to your environment:

```bash
export ANTHROPIC_API_KEY=your_api_key_here
export OPENAI_API_KEY=your_api_key_here
```

## Installation

### Swift Package Manager

Add SwiftAgent to your Swift package dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/1amageek/SwiftAgent.git", branch: "main")
]
```

## Core Components

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

### State Management

SwiftAgent provides two powerful state management mechanisms: Memory and Relay.

#### Memory

Memory is a property wrapper that stores state and provides a Relay projection:

```swift
struct ChatAgent: Agent {
    @Memory private var messages: [Message] = []  // State storage
    @Memory private var context: Context = .init() // Another state
    
    var body: some Step<String, String> {
        MessageTransform(messages: $messages)  // Pass as a binding
        ProcessStep(context: $context)         // Access state via binding
    }
}
```

#### Relay

Relay provides a dynamic way to access and modify state:

```swift
struct ProcessStep: Step {
    @Relay var messages: [Message]    // Receives state from parent
    @Relay var context: Context       // Another state reference
    
    func run(_ input: String) async throws -> String {
        messages.append(Message(content: input))  // Modify state
        context.updateWithMessage(input)          // Update context
        return "Processed: \(input)"
    }
}
```

### Monitoring

SwiftAgent includes built-in monitoring capabilities through the Monitor step wrapper:

```swift
struct LoggingAgent: Agent {
    var body: some Step<String, String> {
        ProcessStep()
            .monitor(
                input: { input in
                    print("Received input: \(input)")
                },
                output: { output in
                    print("Produced output: \(output)")
                }
            )
    }
}
```

You can also monitor just inputs or outputs:

```swift
ProcessStep()
    .onInput { input in 
        print("Input received: \(input)")
    }

ProcessStep()
    .onOutput { output in
        print("Output produced: \(output)")
    }
```

## Usage Examples

### Creating a Chat Agent

```swift
struct ChatAgent: Agent {
    @Memory private var messages: [Message] = []
    
    var body: some Step<String, String> {
        // Transform input into messages
        MessageTransform(messages: $messages)
        
        // Process with LLM
        OllamaModel(model: "llama2", tools: [
            SearchTool(),
            CalculatorTool()
        ]) { tools in
            "You are a helpful assistant"
        }
        .monitor(
            input: { print("Model input: \($0)") },
            output: { print("Model output: \($0)") }
        )
        
        // Store assistant response
        MessageStore(messages: $messages)
    }
}
```

### Conditional Steps

```swift
struct SmartAgent: Agent {
    @Memory private var context: Context = .init()
    
    var body: some Step<Query, Response> {
        if context.requiresSearch {
            SearchStep()
        } else {
            DirectResponseStep()
        }
    }
}
```

### Loops

```swift
struct IterativeAgent: Agent {
    @Memory private var state: ProcessingState = .init()
    
    var body: some Step<Data, Result> {
        Loop(max: 5) { input in
            ProcessingStep(state: $state)
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

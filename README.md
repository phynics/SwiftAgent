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

### Steps and Sequential Execution

Steps are the fundamental building blocks in SwiftAgent. While steps are declared in a declarative SwiftUI-like syntax, they are executed sequentially, with each step's output becoming the input for the next step.

```swift
public protocol Step<Input, Output> {
    associatedtype Input: Sendable
    associatedtype Output: Sendable
    
    func run(_ input: Input) async throws -> Output
}
```

Steps are composed using the `@StepBuilder` result builder, which automatically chains them together based on their input and output types. For example:

```swift
struct TextProcessingAgent: Agent {
    var body: some Step<String, String> {
        // These steps are executed sequentially:
        TokenizeStep()        // String -> [String]
        FilterStep()          // [String] -> [String]
        JoinStep()           // [String] -> String
    }
}
```

In this example, while the steps are written declaratively, they execute in order:
1. First, `TokenizeStep` runs and splits the input string into tokens
2. Then, `FilterStep` processes the tokens array
3. Finally, `JoinStep` combines the filtered tokens back into a string

The framework enforces this sequential flow through type checking at compile time. Each step must accept the output type of the previous step as its input type.

The `StepBuilder` supports up to 8 sequential steps and includes support for conditional execution:

```swift
struct ConditionalAgent: Agent {
    @Memory var shouldFilter: Bool = true
    
    var body: some Step<String, String> {
        TokenizeStep()
        
        if shouldFilter {
            FilterStep()
        }
        
        JoinStep()
    }
}
```

You can also create loops using the `Loop` type:

```swift
struct IterativeAgent: Agent {
    var body: some Step<Data, ProcessedData> {
        Loop(max: 5) { input in
            ProcessingStep()
        } until: { output in
            output.isFullyProcessed
        }
    }
}
```

Behind the scenes, the `StepBuilder` creates a chain of steps using types like `Chain2`, `Chain3`, etc., which handle the sequential execution:

```swift
public struct Chain2<S1: Step, S2: Step>: Step where S1.Output == S2.Input {
    public func run(_ input: Input) async throws -> Output {
        let intermediate = try await step1.run(input)
        return try await step2.run(intermediate)
    }
}
```

This combination of declarative syntax and sequential execution provides a clear, type-safe way to compose complex agent workflows while maintaining the familiar Swift syntax.

### Tools

Tools are special types of Steps that represent capabilities that can be used by agents. They provide a standardized interface for external operations and include comprehensive documentation:

```swift
public protocol Tool: Identifiable, Step where Input: Codable, Output: Codable & CustomStringConvertible {
    /// A unique name identifying the tool
    var name: String { get }
    
    /// A description of what the tool does
    var description: String { get }
    
    /// JSON schema defining the tool's input/output structure
    var parameters: JSONSchema { get }
    
    /// Detailed guide for using the tool
    var guide: String? { get }
}
```

Tools must include:
- Unique identifying name
- Description of functionality
- JSON schema for input/output validation
- Optional detailed usage guide with examples
- Implementation of the `run` method from the `Step` protocol

Example of implementing a tool:

```swift
struct SearchTool: Tool {
    var name: String { "search" }
    var description: String { "Searches the web for information" }
    
    var parameters: JSONSchema {
        .object(
            title: "SearchParameters",
            properties: [
                "query": .string(description: "The search query"),
                "limit": .integer(description: "Maximum number of results", default: 10)
            ],
            required: ["query"]
        )
    }
    
    var guide: String? {
        """
        # Search Tool
        
        Performs web searches and returns relevant results.
        
        ## Parameters
        - query: Search terms (required)
        - limit: Max results (optional, default: 10)
        
        ## Usage
        - Provide specific search terms
        - Results are ranked by relevance
        
        ## Examples
        ```json
        {
            "query": "Swift programming",
            "limit": 5
        }
        ```
        """
    }
    
    func run(_ input: Input) async throws -> Output {
        // Implementation
    }
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

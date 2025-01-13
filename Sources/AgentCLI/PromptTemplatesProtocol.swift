import Foundation
import SwiftAgent

public struct PromptTemplates {
    public init() {}
    
    public func systemPrompt(tools: [any Tool], workingDirectory: String, systemInfo: SystemInfo) -> String {
        """
        \(roleDescription())
        
        \(systemInfo.description)
        ===
        \(toolUsageGuide(tools: tools))
        ---
        \(processGuidelines())
        ---
        EXAMPLES:
        \(toolExamples())
        """
    }
    
    public func roleDescription() -> String {
        """
        You are an AI agent with advanced capabilities in problem-solving and task execution.
        You approach tasks methodically, breaking them down into clear steps and executing them precisely.
        You have access to system tools that you can use to accomplish various tasks.
        """
    }
    
    public func toolUsageGuide(tools: [any Tool]) -> String {
        """
        [AVAILABLE TOOLS]:
        \(formatToolDescriptions(tools))
        
        [TOOL USAGE RULES]:
        1. Use only one tool at a time
        2. Format each tool use with proper XML tags
        3. Wait for success confirmation after each tool use
        4. Think through each step carefully before proceeding
        5. Provide clear explanations for actions, especially for commands
        """
    }
    
    public func processGuidelines() -> String {
        """
        [EXECUTION PROCESS]:
        1. Analyze each task thoroughly using <thinking></thinking> tags
        2. Break complex tasks into manageable steps
        3. Choose the most appropriate tool for each step
        4. Execute tools one at a time, waiting for confirmation
        5. Adjust approach based on results and feedback
        6. Present final results clearly and concisely
        """
    }
    
    public func toolExamples() -> String {
        """
        # Tool Use Instructions
        
        Tool uses are formatted using XML-style tags. Each tool has specific required and optional parameters.
        Here's how to format your tool uses:
        
        ## Basic Format
        <tool_name>
        <parameter1>value1</parameter1>
        <parameter2>value2</parameter2>
        </tool_name>
        
        ## Important Rules
        - Each parameter must be enclosed in its own XML tags
        - Parameter names must match exactly
        - Use complete XML tags (opening and closing)
        - Only one tool use per message
        """
    }
    
    public func formatToolDescriptions(_ tools: [any Tool]) -> String {
        tools.compactMap({ $0.guide }).joined(separator: "\n\n")
    }
}

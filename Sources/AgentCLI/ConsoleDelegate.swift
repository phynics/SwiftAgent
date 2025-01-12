////
////  ConsoleDelegate.swift
////  SwiftAgent
////
////  Created by Norikazu Muramoto on 2025/01/11.
////
//
//import Foundation
//import SwiftAgent
//
///// Enhanced console delegate that provides real-time feedback of agent operations
///// with colored output, progress indicators, and timing information
//public actor ConsoleDelegate: AgentDelegate {
//    
//    /// ANSI escape codes for terminal colors and styles
//    private enum ANSIColor {
//        static let reset = "\u{001B}[0m"
//        static let bold = "\u{001B}[1m"
//        static let dim = "\u{001B}[2m"
//        static let italic = "\u{001B}[3m"
//        static let red = "\u{001B}[31m"
//        static let green = "\u{001B}[32m"
//        static let yellow = "\u{001B}[33m"
//        static let blue = "\u{001B}[34m"
//        static let magenta = "\u{001B}[35m"
//        static let cyan = "\u{001B}[36m"
//    }
//    
//    /// Formatter for timestamps in console output
//    private let dateFormatter: DateFormatter = {
//        let formatter = DateFormatter()
//        formatter.dateFormat = "HH:mm:ss.SSS"
//        return formatter
//    }()
//    
//    /// Progress indicator for ongoing operations
//    private var progressIndex = 0
//    private let progressIndicators = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
//    
//    /// Timer for updating the spinner animation
//    @MainActor private var spinnerTimer: Timer?
//    
//    /// Timestamp when processing started
//    private var startTime: Date?
//    
//    /// Counter for indentation level
//    private var indentationLevel = 0
//    
//    public init() {}
//    
//    public func agent(_ agent: Agent, didChangeStatus status: AgentStatus) async {
//        let timestamp = dateFormatter.string(from: Date())
//        let statusIcon = icon(for: status)
//        let statusText = statusDescription(for: status)
//        
//        switch status {
//        case .ready:
//            print("[\(timestamp)] \(ANSIColor.cyan)\(statusIcon) \(statusText)\(ANSIColor.reset)")
//            
//        case .processing:
//            startTime = Date()
//            print("[\(timestamp)] \(ANSIColor.yellow)\(statusIcon) \(statusText)\(ANSIColor.reset)")
//            await startSpinner()
//            
//        case .usingTool(_):
//            print("[\(timestamp)] \(ANSIColor.blue)\(statusIcon) \(statusText)\(ANSIColor.reset)")
//            
//        case .finished:
//            await stopSpinner()
//            if let start = startTime {
//                let duration = Date().timeIntervalSince(start)
//                print("[\(timestamp)] \(ANSIColor.green)\(statusIcon) \(statusText)\(ANSIColor.reset)")
//                print("[\(timestamp)] \(ANSIColor.green)✨ Completed in \(String(format: "%.2f", duration))s\(ANSIColor.reset)")
//            }
//            
//        case .error(let error):
//            await stopSpinner()
//            print("[\(timestamp)] \(ANSIColor.red)\(statusIcon) \(statusText)\(ANSIColor.reset)")
//            print("[\(timestamp)] \(ANSIColor.red)❌ Error details: \(error.localizedDescription)\(ANSIColor.reset)")
//        }
//    }
//    
//    public func agent(_ agent: Agent, didAddThought thought: Thought) async {
//        let timestamp = dateFormatter.string(from: Date())
//        let thoughtIcon = icon(for: thought.type)
//        
//        await stopSpinner() // Pause spinner while showing thought
//        
//        // 思考タイプに基づいて適切なフォーマットを適用
//        let formattedContent = formatThoughtContent(thought.content, type: thought.type)
//        print("\n[\(timestamp)] \(thoughtIcon) \(formattedContent)")
//        
//        if case .processing = await agent.status {
//            await startSpinner() // Resume spinner if still processing
//        }
//    }
//    
//    public func agent(_ agent: Agent, willUseTool name: String) async {
//        let timestamp = dateFormatter.string(from: Date())
//        await stopSpinner()
//        print("[\(timestamp)] \(ANSIColor.blue)🛠 Using tool: \(name)\(ANSIColor.reset)")
//        await startSpinner()
//    }
//    
//    public func agent(_ agent: Agent, didUseTool name: String, result: ToolResult) async {
//        let timestamp = dateFormatter.string(from: Date())
//        await stopSpinner()
//        
//        if result.success {
//            print("[\(timestamp)] \(ANSIColor.green)✅ Tool '\(name)' completed successfully\(ANSIColor.reset)")
//            
//            // Format tool output with indentation
//            let formattedOutput = result.output
//                .split(separator: "\n")
//                .map { "    \($0)" }
//                .joined(separator: "\n")
//            
//            if !result.output.isEmpty {
//                print("[\(timestamp)] \(ANSIColor.dim)📤 Output:\(ANSIColor.reset)\n\(formattedOutput)")
//            }
//        } else {
//            print("[\(timestamp)] \(ANSIColor.red)❌ Tool '\(name)' failed\(ANSIColor.reset)")
//            
//            if let error = result.error {
//                print("[\(timestamp)] \(ANSIColor.red)⚠️ Error: \(error.localizedDescription)\(ANSIColor.reset)")
//            }
//        }
//        
//        if case .processing = await agent.status {
//            await startSpinner()
//        }
//    }
//    
//    // MARK: - Private Helper Methods
//    
//    private func icon(for status: AgentStatus) -> String {
//        switch status {
//        case .ready: return "📍"
//        case .processing: return "🔄"
//        case .usingTool: return "🛠"
//        case .finished: return "✅"
//        case .error: return "❌"
//        }
//    }
//    
//    private func icon(for thoughtType: ThoughtType) -> String {
//        switch thoughtType {
//        case .observation: return "👀"
//        case .reasoning: return "🤔"
//        case .action: return "🎯"
//        case .conclusion: return "✅"
//        }
//    }
//    
//    private func statusDescription(for status: AgentStatus) -> String {
//        switch status {
//        case .ready:
//            return "Agent ready for new task"
//        case .processing:
//            return "Processing request..."
//        case .usingTool(let name):
//            return "Using tool: \(name)"
//        case .finished:
//            return "Task completed successfully"
//        case .error(let error):
//            return "Error occurred: \(error.localizedDescription)"
//        }
//    }
//    
//    private func formatThoughtContent(_ content: String, type: ThoughtType) -> String {
//        let (color, prefix): (String, String) = switch type {
//        case .observation:
//            (ANSIColor.cyan, "Observed")
//        case .reasoning:
//            (ANSIColor.yellow, "Thinking")
//        case .action:
//            (ANSIColor.blue, "Action")
//        case .conclusion:
//            (ANSIColor.green, "Concluded")
//        }
//        
//        // XML タグやマークダウンの処理
//        let processedContent = content
//            .replacingOccurrences(of: "<thinking>", with: "")
//            .replacingOccurrences(of: "</thinking>", with: "")
//            .replacingOccurrences(of: "<observation>", with: "")
//            .replacingOccurrences(of: "</observation>", with: "")
//        
//        // 思考内容を整形
//        let formattedLines = processedContent
//            .split(separator: "\n")
//            .map { line -> String in
//                if line.trimmingCharacters(in: .whitespaces).isEmpty {
//                    return ""
//                }
//                return "    \(color)\(line)\(ANSIColor.reset)"
//            }
//            .filter { !$0.isEmpty }
//        
//        // プレフィックスと内容を結合
//        return "\(color)\(prefix):\(ANSIColor.reset)\n\(formattedLines.joined(separator: "\n"))"
//    }
//    
//    @MainActor private func startSpinner() async {
//        guard spinnerTimer == nil else { return }
//        
//        spinnerTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
//            guard let self = self else { return }
//            
//            Task {
//                await self.updateSpinner()
//            }
//        }
//    }
//    
//    @MainActor private func stopSpinner() async {
//        spinnerTimer?.invalidate()
//        spinnerTimer = nil
//        // Clear the spinner line
//        print("\u{001B}[1A\u{001B}[2K", terminator: "")
//    }
//    
//    private func updateSpinner() async {
//        progressIndex = (progressIndex + 1) % progressIndicators.count
//        let spinner = progressIndicators[progressIndex]
//        // Move cursor up one line and clear it
//        await MainActor.run {
//            print("\u{001B}[1A\u{001B}[2K\r\(ANSIColor.cyan)\(spinner) Thinking...\(ANSIColor.reset)")
//        }
//    }
//}

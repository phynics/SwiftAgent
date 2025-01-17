//
//  TaskCompletion.swift
//  SwiftAgent
//
//  Created by Norikazu Muramoto on 2025/01/17.
//

import Foundation
import JSONSchema

/// タスクの完了状態を表す構造体
public struct TaskCompletion: Codable, Sendable {
    let isComplete: Bool           // タスクが完了したか
    let nextTaskId: String?        // 次のタスクID
    let error: String?            // エラーメッセージ（あれば）
}

/// TaskCompletionのJSONSchema定義
public let TaskCompletionSchema: JSONSchema = .object(
    description: "Task completion status check",
    properties: [
        "isComplete": .boolean(description: "Whether the task is completed"),
        "nextTaskId": .string(description: "ID of the next task to execute"),
        "error": .string(description: "Error message if any")
    ],
    required: ["isComplete"],
    additionalProperties: .boolean(false)
)

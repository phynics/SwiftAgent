//
//  Novel.swift
//  SwiftAgent
//
//  Created by Norikazu Muramoto on 2025/01/15.
//

import Foundation
import JSONSchema

struct Novel: Codable {
    var chapters: [Chapter]
}

struct Chapter: Codable {
    struct Setting: Codable {
        let location: String
        let timePeriod: String
    }
    
    struct Character: Codable {
        let name: String
        let role: String
    }
    
    struct PlotPoint: Codable {
        let scene: Int
        let description: String
    }
    
    let number: Int
    let title: String
    let summary: String
    let setting: Setting
    let characters: [Character]
    let plotPoints: [PlotPoint]
    let theme: String
}

let ChaptersJSONSchema: JSONSchema = .object(
    description: "An object containing an array of simple story chapters",
    properties: [
        "chapters": .array(
            description: "An array of simplified story chapters",
            items: .object(
                description: "Represents a simplified chapter structure",
                properties: [
                    "number": .integer(description: "The chapter number"),
                    "title": .string(description: "The title of the chapter"),
                    "summary": .string(description: "A brief summary of the chapter"),
                    "setting": .object(
                        description: "The setting details of the chapter",
                        properties: [
                            "location": .string(description: "The location of the chapter"),
                            "timePeriod": .string(description: "The time period of the chapter")
                        ],
                        required: ["location", "timePeriod"],
                        additionalProperties: .boolean(false)
                    ),
                    "characters": .array(
                        description: "List of characters in the chapter",
                        items: .object(
                            properties: [
                                "name": .string(description: "The name of the character"),
                                "role": .string(description: "The role of the character")
                            ],
                            required: ["name", "role"],
                            additionalProperties: .boolean(false)
                        )
                    ),
                    "plotPoints": .array(
                        description: "Key events in the chapter",
                        items: .object(
                            properties: [
                                "scene": .integer(description: "Scene number"),
                                "description": .string(description: "Description of the scene")
                            ],
                            required: ["scene", "description"],
                            additionalProperties: .boolean(false)
                        )
                    ),
                    "theme": .string(description: "The main theme of the chapter")
                ],
                required: ["number", "title", "summary", "setting", "characters", "plotPoints", "theme"],
                additionalProperties: .boolean(false)
            )
        )
    ],
    required: ["chapters"],
    additionalProperties: .boolean(false)
)

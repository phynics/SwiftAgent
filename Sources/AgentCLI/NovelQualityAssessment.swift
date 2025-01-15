//
//  NovelQualityAssessment.swift
//  SwiftAgent
//
//  Created by Norikazu Muramoto on 2025/01/15.
//


// NovelQualityAssessment.swift

import Foundation
import JSONSchema

struct NovelQualityAssessment: Codable {
    let hasGoodCharacters: Bool
    let hasGoodPlot: Bool
    let hasGoodTheme: Bool
    let isHighQuality: Bool
}

let NovelQualityAssessmentSchema: JSONSchema = .object(
    description: "Simple evaluation criteria for novel quality",
    properties: [
        "hasGoodCharacters": .boolean(description: "Characters are well-developed"),
        "hasGoodPlot": .boolean(description: "Plot is engaging and logical"),
        "hasGoodTheme": .boolean(description: "Theme is consistent and meaningful"),
        "isHighQuality": .boolean(description: "Overall quality meets standards")
    ],
    required: ["hasGoodCharacters", "hasGoodPlot", "hasGoodTheme", "isHighQuality"],
    additionalProperties: .boolean(false)
)

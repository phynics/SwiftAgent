//
//  Novelist.swift
//  SwiftAgent
//
//  Created by Norikazu Muramoto on 2025/01/14.
//

import Foundation
import SwiftAgent
import LLMChatOpenAI
import Agents
import JSONSchema


public struct Novelist: Agent {
    public typealias Input = String
    public typealias Output = String
    
    public init() {}
    
    public var body: some Step<Input, Output> {
        
        Loop(max: 2) { request in
            // リクエストをチャットメッセージに変換
            Transform { input -> [ChatMessage] in
                [ChatMessage(role: .user, content: [.text(input)])]
            }
            
            OpenAIModel<Novel>(schema: ChaptersJSONSchema) { _ in
                """
                あなたは小説家です。
                以下の要件に基づいて、物語の詳細な章立てをJSONで出力してください。
                                
                - 各章には魅力的なキャラクター、効果的な伏線、印象的な対話を含めてください
                - キャラクターの成長や変化を描写してください
                - 一貫性のあるテーマを維持しながら、物語を展開してください
                """
            }
            .onOutput { novel in
                print(novel)
            }
            Transform<Novel, [Chapter]> { novel -> [Chapter] in
                novel.chapters
            }
            // 各チャプターを物語形式に変換
            Map<[Chapter], [String]> { chapter, index in
                Transform<Chapter, [ChatMessage]> { chapter -> [ChatMessage] in
                    [ChatMessage(role: .user, content: [.text(prompt(for: chapter))])]
                }
                OpenAIModel { _ in
                "プロットに沿って小説の章を書いて下さい"
                }
            }
            // 章を結合して最終的な小説に
            Join()
        } until: {
            Transform<String, [ChatMessage]> { novel -> [ChatMessage] in
                [ChatMessage(role: .user, content: [.text(
                    """
                    この小説を評価してください:
                    
                    \(novel)
                    """)])]
            }
            
            OpenAIModel<NovelQualityAssessment>(schema: NovelQualityAssessmentSchema) { _ in
                    """
                    小説の品質を以下の観点で評価してください：
                    - キャラクター性
                    - プロットの展開
                    - テーマ性
                    - 全体的な品質
                    """
            }
            
            Transform<NovelQualityAssessment, Bool> { assessment in
                assessment.hasGoodCharacters &&
                assessment.hasGoodPlot &&
                assessment.hasGoodTheme &&
                assessment.isHighQuality
            }
        }
    }
    
    func prompt(for chapter: Chapter) -> String {
        // キャラクター情報の整形
        let characters = chapter.characters.map { char in
            "- \(char.name)（\(char.role)）"
        }.joined(separator: "\n")
        
        // プロットポイントの整形
        let plotPoints = chapter.plotPoints.map { point in
            "シーン\(point.scene): \(point.description)"
        }.joined(separator: "\n")
        
        // 章全体の情報を整形
        return """
        第\(chapter.number)章: \(chapter.title)
        
        [概要]
        \(chapter.summary)
        
        [舞台設定]
        場所: \(chapter.setting.location)
        時代: \(chapter.setting.timePeriod)
        
        [登場人物]
        \(characters)
        
        [展開]
        \(plotPoints)
        
        [テーマ]
        \(chapter.theme)
        """
    }

}

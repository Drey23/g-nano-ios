//
//  models.swift
//  g-nano-ios
//
//  Created by Andrey Lindo on 6/8/26.
//

import FoundationModels

// 1. Update the structured output to match our new goal
@Generable
struct DetectionResult: Codable {
    var isFound: Bool
    var details: String
}

@Generable
struct ModerationResult: Codable {
    var isViolating: Bool
    var reason: String
}

//
//  FigmaCompareResponse.swift
//  ClaudeBugPoC
//

import Foundation

// MARK: - Difference Category
enum FigmaDifferenceCategory: String {
    case layout
    case color
    case typography
    case spacing
    case missing
    case extraElement = "extra"
    case icons
    case other

    var localizationKey: String {
        switch self {
        case .layout: return LocalizationKey.View.FigmaCompare.categoryLayout
        case .color: return LocalizationKey.View.FigmaCompare.categoryColor
        case .typography: return LocalizationKey.View.FigmaCompare.categoryTypography
        case .spacing: return LocalizationKey.View.FigmaCompare.categorySpacing
        case .missing: return LocalizationKey.View.FigmaCompare.categoryMissing
        case .extraElement: return LocalizationKey.View.FigmaCompare.categoryExtra
        case .icons: return LocalizationKey.View.FigmaCompare.categoryIcons
        case .other: return LocalizationKey.View.FigmaCompare.categoryOther
        }
    }
}

// MARK: - Severity
enum FigmaDifferenceSeverity: String {
    case high
    case medium
    case low

    var localizationKey: String {
        switch self {
        case .high: return LocalizationKey.View.FigmaCompare.severityHigh
        case .medium: return LocalizationKey.View.FigmaCompare.severityMedium
        case .low: return LocalizationKey.View.FigmaCompare.severityLow
        }
    }

    var order: Int {
        switch self {
        case .high: return 0
        case .medium: return 1
        case .low: return 2
        }
    }
}

// MARK: - Difference
struct FigmaDifference {
    let category: FigmaDifferenceCategory
    let severity: FigmaDifferenceSeverity
    let title: String
    let detail: String
    let codeHint: String?

    init?(dictionary: [String: Any]) {
        guard let categoryRaw = dictionary["category"] as? String,
              let severityRaw = dictionary["severity"] as? String,
              let title = dictionary["title"] as? String,
              let detail = dictionary["detail"] as? String else {
            return nil
        }
        self.category = FigmaDifferenceCategory(rawValue: categoryRaw) ?? .other
        self.severity = FigmaDifferenceSeverity(rawValue: severityRaw) ?? .medium
        self.title = title
        self.detail = detail
        self.codeHint = dictionary["codeHint"] as? String
    }
}

// MARK: - Response
struct FigmaCompareResponse {
    let detectedScreen: String?
    let summary: String?
    let differences: [FigmaDifference]
    let iterations: Int
    let inputTokens: Int
    let outputTokens: Int
    let estimatedCostUsd: Double

    init?(dictionary: [String: Any]) {
        guard let rawDiffs = dictionary["differences"] as? [[String: Any]] else {
            return nil
        }
        self.detectedScreen = dictionary["detectedScreen"] as? String
        self.summary = dictionary["summary"] as? String
        self.differences = rawDiffs.compactMap(FigmaDifference.init(dictionary:))
        self.iterations = dictionary["iterations"] as? Int ?? 0
        self.inputTokens = dictionary["inputTokens"] as? Int ?? 0
        self.outputTokens = dictionary["outputTokens"] as? Int ?? 0
        self.estimatedCostUsd = dictionary["estimatedCostUsd"] as? Double ?? 0
    }
}

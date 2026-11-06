import Foundation

public enum SummaryLength: String, Codable, CaseIterable, Sendable {
    case brief, standard, detailed

    public var displayName: String {
        switch self {
        case .brief: "Brief"
        case .standard: "Standard"
        case .detailed: "Detailed"
        }
    }

    var instruction: String {
        switch self {
        case .brief:
            "Write a one-sentence TL;DR in bold, then exactly 3 short bullet points with the key points."
        case .standard:
            "Write a one-sentence TL;DR in bold, then 5–7 bullet points covering the key points, then one line starting with “Why it matters:”."
        case .detailed:
            "Write a one-sentence TL;DR in bold, then a structured summary with short `###` section headings that follow the document's own structure, using bullet points under each."
        }
    }

    var maxOutputTokens: Int {
        switch self {
        case .brief: 600
        case .standard: 1_200
        case .detailed: 3_000
        }
    }
}

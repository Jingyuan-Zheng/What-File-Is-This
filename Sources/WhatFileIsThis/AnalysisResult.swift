import Foundation

struct AnalysisResult: Equatable, Sendable {
    var fileName: String
    var what: String
    var belongsTo: String
    var purpose: String
    var openWith: String?
    var deletion: String
    var source: String
    var confidence: String
    var evidence: [String]
    var rawText: String
    var targetPath: String?

    var displayPath: String? {
        guard let targetPath, !targetPath.isEmpty else { return nil }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if targetPath == home { return "~" }
        if targetPath.hasPrefix(home + "/") {
            return "~" + String(targetPath.dropFirst(home.count))
        }
        return targetPath
    }

    var targetURL: URL? {
        guard let targetPath, !targetPath.isEmpty else { return nil }
        return URL(fileURLWithPath: targetPath)
    }
}

struct ParsedResultFile: Sendable {
    var analysis: AnalysisResult?
    var isLoading: Bool
    var deleteAfterOpen: Bool

    init(
        analysis: AnalysisResult?,
        isLoading: Bool = false,
        deleteAfterOpen: Bool = false
    ) {
        self.analysis = analysis
        self.isLoading = isLoading
        self.deleteAfterOpen = deleteAfterOpen
    }
}

enum ResultReadError: LocalizedError {
    case unreadable
    case invalidFormat
    case missingAnalysis

    var errorDescription: String? {
        switch self {
        case .unreadable:
            return L10n.ui("Unable to read the result file.")
        case .invalidFormat:
            return L10n.ui("The result file format is not recognized.")
        case .missingAnalysis:
            return L10n.ui("The result file does not contain analysis to display.")
        }
    }
}

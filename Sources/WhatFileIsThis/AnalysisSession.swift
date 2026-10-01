import AppKit
import Observation
import SwiftUI

@MainActor
@Observable
final class AnalysisSession {
    let id: String
    var analysis: AnalysisResult?

    init(id: String) {
        self.id = id
    }
}

struct AnalysisSessionView: View {
    let session: AnalysisSession

    var body: some View {
        Group {
            if let analysis = session.analysis {
                AnalysisView(
                    analysis: analysis,
                    onCopy: { copy(analysis.rawText) },
                    onRevealInFinder: { reveal(analysis.targetURL) },
                    onClose: closeWindow
                )
            } else {
                LoadingView()
            }
        }
    }

    private func copy(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func reveal(_ url: URL?) {
        guard let url, FileManager.default.fileExists(atPath: url.path) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func closeWindow() {
        NSApp.keyWindow?.performClose(nil)
    }
}

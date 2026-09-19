import AppKit
import Combine
import Foundation

@MainActor
final class ResultStore: ObservableObject {
    static let shared = ResultStore()

    @Published var analysis: AnalysisResult?
    @Published var errorMessage: String?

    private init() {}

    func open(urls: [URL]) {
        guard let url = urls.first else { return }
        load(url: url)
    }

    func load(url: URL) {
        do {
            let parsed = try ResultParser.parseResultFile(at: url)
            analysis = parsed.analysis
            errorMessage = nil

            if parsed.deleteAfterOpen {
                let temp = URL(fileURLWithPath: NSTemporaryDirectory()).standardizedFileURL.path
                let path = url.standardizedFileURL.path
                if path.hasPrefix(temp) {
                    try? FileManager.default.removeItem(at: url)
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func loadCommandLineArgumentsIfNeeded() {
        guard analysis == nil else { return }

        let arguments = Array(CommandLine.arguments.dropFirst())

        // Preferred bridge used by the Shortcut: launch a fresh app instance with
        //   --wfit-result /path/to/result.wfitresult
        if let flagIndex = arguments.firstIndex(of: "--wfit-result"),
           arguments.indices.contains(flagIndex + 1) {
            let candidate = URL(fileURLWithPath: arguments[flagIndex + 1])
            if FileManager.default.fileExists(atPath: candidate.path) {
                load(url: candidate)
                return
            }
        }

        // Backward-compatible fallback: accept any existing file path argument.
        for argument in arguments where !argument.hasPrefix("-") {
            let candidate = URL(fileURLWithPath: argument)
            if FileManager.default.fileExists(atPath: candidate.path) {
                load(url: candidate)
                return
            }
        }
    }

    func copyResult() {
        guard let analysis else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(analysis.rawText, forType: .string)
    }

    func revealInFinder() {
        guard let url = analysis?.targetURL,
              FileManager.default.fileExists(atPath: url.path) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func closeWindow() {
        NSApplication.shared.keyWindow?.performClose(nil)
    }
}

import AppKit
import Combine
import Foundation

@MainActor
final class ResultStore: ObservableObject {
    static let shared = ResultStore()

    @Published var analysis: AnalysisResult?
    @Published var errorMessage: String?
    @Published private(set) var isWaitingForResult = false

    private var pendingResultURL: URL?
    private var pendingResultTimer: Timer?

    private init() {}

    func open(urls: [URL]) {
        guard let url = urls.first else { return }
        load(url: url)
    }

    func load(url: URL) {
        stopWaitingForResult()
        do {
            let parsed = try ResultParser.parseResultFile(at: url)
            analysis = parsed.analysis
            errorMessage = nil

            if parsed.deleteAfterOpen {
                let temp = URL(fileURLWithPath: NSTemporaryDirectory()).standardizedFileURL.path
                let path = url.standardizedFileURL.path
                if path.hasPrefix(temp) || path == pendingResultURL?.standardizedFileURL.path {
                    try? FileManager.default.removeItem(at: url)
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        presentWindow()
    }

    func waitForResult(at url: URL) {
        stopWaitingForResult()
        analysis = nil
        errorMessage = nil
        pendingResultURL = url
        isWaitingForResult = true

        pendingResultTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let pendingResultURL = self.pendingResultURL else { return }
                guard FileManager.default.fileExists(atPath: pendingResultURL.path) else { return }
                self.load(url: pendingResultURL)
            }
        }
        RunLoop.main.add(pendingResultTimer!, forMode: .common)
        presentWindow()
    }

    private func stopWaitingForResult() {
        pendingResultTimer?.invalidate()
        pendingResultTimer = nil
        isWaitingForResult = false
    }

    private func presentWindow() {
        WindowPresenter.present()
    }

    func loadCommandLineArgumentsIfNeeded() {
        guard analysis == nil else { return }

        let arguments = Array(CommandLine.arguments.dropFirst())

        // Preferred bridge used by the Shortcut: launch a fresh app instance with
        //   --wfit-result /path/to/result.wfitresult
        if let flagIndex = arguments.firstIndex(of: "--wfit-result"),
           arguments.indices.contains(flagIndex + 1) {
            let candidate = URL(fileURLWithPath: arguments[flagIndex + 1])
            if arguments.contains("--wfit-loading") {
                waitForResult(at: candidate)
                return
            }
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

import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var sessions: [String: AnalysisSession] = [:]
    private var sessionWindows: [String: NSWindowController] = [:]
    private lazy var resultServer = LocalResultServer { [weak self] payload in
        self?.apply(payload)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        try? resultServer.start()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            handle(url)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        resultServer.stop()
    }

    private func handle(_ url: URL) {
        guard url.scheme?.lowercased() == "whatfileisthis",
              let command = url.host?.lowercased(),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let id = components.queryItems?.first(where: { $0.name == "id" })?.value,
              !id.isEmpty else { return }

        switch command {
        case "loading":
            showSession(id: id)
        default:
            return
        }
    }

    private func showSession(id: String) {
        if let window = sessionWindows[id]?.window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }

        let session = sessions[id] ?? AnalysisSession(id: id)
        sessions[id] = session

        let controller = NSHostingController(rootView: AnalysisSessionView(session: session))
        let window = NSWindow(contentViewController: controller)
        window.title = "What File Is This"
        window.setContentSize(NSSize(width: 780, height: 660))
        window.minSize = NSSize(width: 680, height: 500)
        window.isReleasedWhenClosed = false

        let windowController = NSWindowController(window: window)
        sessionWindows[id] = windowController
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.sessionWindows.removeValue(forKey: id)
                self?.sessions.removeValue(forKey: id)
            }
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    private func apply(_ payload: LocalResultPayload) {
        guard let pathData = Data(base64Encoded: payload.pathB64),
              let path = String(data: pathData, encoding: .utf8),
              let resultData = Data(base64Encoded: payload.resultB64),
              let resultText = String(data: resultData, encoding: .utf8),
              !payload.id.isEmpty else { return }

        let session = sessions[payload.id] ?? AnalysisSession(id: payload.id)
        session.analysis = ResultParser.parseSectionedAnalysis(resultText, targetPath: path)
        sessions[payload.id] = session
        showSession(id: payload.id)
    }

    func showAboutPanel(language: AppLanguage) {
        NSApp.orderFrontStandardAboutPanel(options: [.credits: aboutCredits(language: language)])
        NSApp.activate()
    }

    private func aboutCredits(language: AppLanguage) -> NSAttributedString {
        let website = URL(string: "https://jingyuan.is-a.dev")!
        let repository = URL(string: "https://github.com/jingyuan-zheng/What-File-Is-This")!
        let credits = NSMutableAttributedString(string: L10n.string("about.credits", language: language), attributes: [.font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize), .paragraphStyle: centeredParagraphStyle()])
        let text = credits.string as NSString
        credits.addAttribute(.link, value: website, range: text.range(of: L10n.string("about.website", language: language)))
        credits.addAttribute(.link, value: repository, range: text.range(of: L10n.string("about.repository", language: language)))
        credits.addAttribute(.link, value: repository, range: text.range(of: L10n.string("about.license", language: language)))
        return credits
    }

    private func centeredParagraphStyle() -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        return style
    }
}

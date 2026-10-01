import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var sessions: [String: AnalysisSession] = [:]
    private var sessionWindows: [String: NSWindowController] = [:]
    private var resultFiles: Set<URL> = []

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            handle(url)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        for url in resultFiles where isManagedResultFile(url) {
            try? FileManager.default.removeItem(at: url)
        }
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
        case "result":
            guard let encodedPath = components.queryItems?.first(where: { $0.name == "file_b64" })?.value,
                  let path = decodeBase64URL(encodedPath),
                  !path.isEmpty else { return }
            applyResult(at: URL(fileURLWithPath: path), to: id)
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

    private func applyResult(at url: URL, to id: String) {
        guard isManagedResultFile(url),
              let parsed = try? ResultParser.parseResultFile(at: url) else { return }
        resultFiles.insert(url.standardizedFileURL)
        let session = sessions[id] ?? AnalysisSession(id: id)
        session.analysis = parsed.analysis
        sessions[id] = session
        showSession(id: id)
    }

    private func isManagedResultFile(_ url: URL) -> Bool {
        let cache = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches/WhatFileIsThis", isDirectory: true)
            .standardizedFileURL
        let candidate = url.standardizedFileURL
        return candidate.path.hasPrefix(cache.path + "/") && candidate.pathExtension == "wfitresult"
    }

    private func decodeBase64URL(_ value: String) -> String? {
        var base64 = value.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        guard let data = Data(base64Encoded: base64) else { return nil }
        return String(data: data, encoding: .utf8)
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

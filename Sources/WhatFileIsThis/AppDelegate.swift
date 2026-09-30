import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: NSWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        createMainWindowIfNeeded()
        ResultStore.shared.loadCommandLineArgumentsIfNeeded()
        presentWindow()
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        ResultStore.shared.open(urls: filenames.map { URL(fileURLWithPath: $0) })
        sender.reply(toOpenOrPrint: .success)
        presentWindow()
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        ResultStore.shared.open(urls: [URL(fileURLWithPath: filename)])
        presentWindow()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func showAboutPanel(language: AppLanguage) {
        NSApp.orderFrontStandardAboutPanel(options: [.credits: aboutCredits(language: language)])
        NSApp.activate(ignoringOtherApps: true)
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

    private func createMainWindowIfNeeded() {
        guard windowController == nil else { return }

        let rootView = RootView()
            .environmentObject(ResultStore.shared)
            .frame(minWidth: 680, minHeight: 500)
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 780, height: 660),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = "What File Is This"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false

        let controller = NSWindowController(window: window)
        windowController = controller
        controller.showWindow(nil)
        window.contentView?.layoutSubtreeIfNeeded()
        centerOnActiveScreen(window)

        // SwiftUI resolves its initial fitting size on the next run-loop pass.
        // Center once more after that size settles, but never during later updates.
        DispatchQueue.main.async { [weak self, weak window] in
            guard let self, let window else { return }
            window.contentView?.layoutSubtreeIfNeeded()
            self.centerOnActiveScreen(window)
        }
    }

    private func centerOnActiveScreen(_ window: NSWindow) {
        let pointerLocation = NSEvent.mouseLocation
        let activeScreen = NSScreen.screens.first {
            NSMouseInRect(pointerLocation, $0.frame, false)
        } ?? NSScreen.main ?? NSScreen.screens.first

        guard let visibleFrame = activeScreen?.visibleFrame else {
            window.center()
            return
        }

        let origin = NSPoint(
            x: visibleFrame.midX - window.frame.width / 2,
            y: visibleFrame.midY - window.frame.height / 2
        )
        window.setFrameOrigin(origin)
    }

    private func presentWindow() {
        WindowPresenter.present()
    }
}

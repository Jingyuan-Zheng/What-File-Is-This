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
        window.center()

        let controller = NSWindowController(window: window)
        windowController = controller
        controller.showWindow(nil)
    }

    private func presentWindow() {
        WindowPresenter.present()
    }
}

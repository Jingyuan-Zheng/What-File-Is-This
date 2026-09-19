import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
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

    private func presentWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        DispatchQueue.main.async {
            NSApplication.shared.windows.first?.makeKeyAndOrderFront(nil)
        }
    }
}

import AppKit

@MainActor
enum ResultWindowPresenter {
    private static weak var resultWindow: NSWindow?
    private static var needsPresentation = false

    static func register(_ window: NSWindow) {
        resultWindow = window
        presentIfReady()
    }

    static func requestPresentation() {
        needsPresentation = true
        NSApp.activate()
        presentIfReady()
    }

    static func applicationDidBecomeActive() {
        presentIfReady()
    }

    static func applicationDidResignActive() {
        needsPresentation = false
    }

    private static func presentIfReady() {
        guard needsPresentation,
              NSApp.isActive,
              let resultWindow else { return }

        // Standard AppKit window display only. Do not alter frame, level, or
        // any other scene (including Settings).
        resultWindow.orderFrontRegardless()
        resultWindow.makeKeyAndOrderFront(nil)
        needsPresentation = false
    }
}

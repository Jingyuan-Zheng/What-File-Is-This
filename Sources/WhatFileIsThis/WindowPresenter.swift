import AppKit

@MainActor
enum WindowPresenter {
    private static var presentationGeneration = 0

    /// Brings the app's window forward during launch without making it permanently
    /// float above other applications. A few bounded retries cover the interval in
    /// which SwiftUI creates and attaches its WindowGroup window.
    static func present() {
        presentationGeneration += 1
        let generation = presentationGeneration

        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.unhide(nil)

        for delay in [0.0, 0.15, 0.5, 1.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard generation == presentationGeneration else { return }
                presentAvailableWindows()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            guard generation == presentationGeneration else { return }
            for window in NSApplication.shared.windows where window.level == .floating {
                window.level = .normal
            }
        }
    }

    private static func presentAvailableWindows() {
        NSApplication.shared.unhide(nil)
        NSRunningApplication.current.activate(options: [.activateAllWindows])

        for window in NSApplication.shared.windows where window.canBecomeKey {
            window.collectionBehavior.insert(.moveToActiveSpace)
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.level = .floating
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
        }
    }
}

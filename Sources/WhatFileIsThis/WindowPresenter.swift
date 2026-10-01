import AppKit

@MainActor
enum WindowPresenter {
    private static var presentationGeneration = 0
    private static weak var resultWindow: NSWindow?
    private static var deactivationObserver: NSObjectProtocol?

    /// Presents only the SwiftUI result window. When called before SwiftUI has
    /// attached that window, bounded retries cover the creation interval.
    static func present(window: NSWindow? = nil) {
        if let window {
            presentResultWindow(window)
            return
        }

        presentationGeneration += 1
        let generation = presentationGeneration

        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.unhide(nil)

        for delay in [0.0, 0.15, 0.5, 1.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard generation == presentationGeneration else { return }
                guard let window = primaryResultWindow() else { return }
                present(window)
            }
        }
    }

    /// SwiftUI can attach the NSWindow before it has completed its first
    /// ordering pass. Re-present that exact result window, rather than every
    /// app window, until the ordering settles. App deactivation cancels this.
    private static func presentResultWindow(_ window: NSWindow) {
        presentationGeneration += 1
        let generation = presentationGeneration

        for delay in [0.0, 0.15, 0.5, 1.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard generation == presentationGeneration else { return }
                present(window)
            }
        }
    }

    private static func present(_ window: NSWindow) {
        resultWindow = window
        observeAppDeactivationIfNeeded()

        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.unhide(nil)
        NSApplication.shared.activate()

        window.collectionBehavior.insert(.moveToActiveSpace)
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.level = .floating
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
    }

    private static func primaryResultWindow() -> NSWindow? {
        resultWindow ?? NSApplication.shared.windows.first {
            $0.canBecomeKey && $0.title == "What File Is This"
        }
    }

    private static func observeAppDeactivationIfNeeded() {
        guard deactivationObserver == nil else { return }

        deactivationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: NSApplication.shared,
            queue: .main
        ) { _ in
            Task { @MainActor in
                presentationGeneration += 1
                resultWindow?.level = .normal
            }
        }
    }
}

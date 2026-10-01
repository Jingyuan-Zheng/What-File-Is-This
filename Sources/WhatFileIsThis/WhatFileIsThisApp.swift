import SwiftUI

@main
struct WhatFileIsThisApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private let language = AppLanguage.launchedLanguage

    var body: some Scene {
        Window("What File Is This", id: "result") {
            RootView()
                .environmentObject(ResultStore.shared)
                .frame(minWidth: 680, minHeight: 500)
        }
        .defaultSize(width: 780, height: 660)
        .windowResizability(.contentMinSize)
        .windowStyle(.hiddenTitleBar)
        .defaultLaunchBehavior(.presented)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button(L10n.string("menu.about", language: language)) {
                    appDelegate.showAboutPanel(language: language)
                }
            }
        }

        Settings {
            SettingsView()
        }
    }
}

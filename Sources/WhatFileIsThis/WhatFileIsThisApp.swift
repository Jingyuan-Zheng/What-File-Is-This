import SwiftUI

@main
struct WhatFileIsThisApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private let language = AppLanguage.launchedLanguage

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .appSettings) {}

            CommandGroup(replacing: .appInfo) {
                Button(L10n.string("menu.about", language: language)) {
                    appDelegate.showAboutPanel(language: language)
                }
            }
        }
    }
}

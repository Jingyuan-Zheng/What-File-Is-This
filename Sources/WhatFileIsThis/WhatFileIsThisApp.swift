import SwiftUI

@main
struct WhatFileIsThisApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.english.rawValue

    private var language: AppLanguage { AppLanguage(rawValue: appLanguageRaw) ?? .english }

    var body: some Scene {
        Settings {
            SettingsView()
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button(L10n.string("menu.about", language: language)) {
                    appDelegate.showAboutPanel(language: language)
                }
            }
        }
    }
}

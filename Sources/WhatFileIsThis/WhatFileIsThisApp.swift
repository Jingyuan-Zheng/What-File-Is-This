import SwiftUI

@main
struct WhatFileIsThisApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private let language = AppLanguage.launchedLanguage

    var body: some Scene {
        DocumentGroup { document in
            ResultDocumentView(document: document)
                .frame(minWidth: 680, minHeight: 500)
        }
        makeReadableDocument: { _, _ in
            ResultDocument()
        }
        .defaultSize(width: 780, height: 660)
        .windowResizability(.contentMinSize)
        .windowStyle(.hiddenTitleBar)
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

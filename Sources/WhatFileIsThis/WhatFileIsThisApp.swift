import SwiftUI

@main
struct WhatFileIsThisApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = ResultStore.shared

    var body: some Scene {
        WindowGroup("What File Is This") {
            RootView()
                .environmentObject(store)
                .frame(minWidth: 680, minHeight: 500)
        }
        .defaultSize(width: 780, height: 660)
        .windowResizability(.contentMinSize)
    }
}

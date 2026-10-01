import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        ResultStore.shared.loadCommandLineArgumentsIfNeeded()
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        ResultStore.shared.open(urls: filenames.map { URL(fileURLWithPath: $0) })
        sender.reply(toOpenOrPrint: .success)
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        ResultStore.shared.open(urls: [URL(fileURLWithPath: filename)])
        return true
    }

    func showAboutPanel(language: AppLanguage) {
        NSApp.orderFrontStandardAboutPanel(options: [.credits: aboutCredits(language: language)])
        NSApp.activate()
    }

    private func aboutCredits(language: AppLanguage) -> NSAttributedString {
        let website = URL(string: "https://jingyuan.is-a.dev")!
        let repository = URL(string: "https://github.com/jingyuan-zheng/What-File-Is-This")!
        let credits = NSMutableAttributedString(string: L10n.string("about.credits", language: language), attributes: [.font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize), .paragraphStyle: centeredParagraphStyle()])
        let text = credits.string as NSString
        credits.addAttribute(.link, value: website, range: text.range(of: L10n.string("about.website", language: language)))
        credits.addAttribute(.link, value: repository, range: text.range(of: L10n.string("about.repository", language: language)))
        credits.addAttribute(.link, value: repository, range: text.range(of: L10n.string("about.license", language: language)))
        return credits
    }

    private func centeredParagraphStyle() -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        return style
    }

}

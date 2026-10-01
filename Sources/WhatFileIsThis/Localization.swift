import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var id: String { rawValue }
    var locale: Locale { Locale(identifier: rawValue) }
    var nativeName: String { self == .english ? "English" : "简体中文" }

    static let launchedLanguage = AppLanguage(
        rawValue: UserDefaults.standard.string(forKey: "appLanguage") ?? AppLanguage.english.rawValue
    ) ?? .english
}

enum L10n {
    static func string(_ key: String, language: AppLanguage, _ arguments: CVarArg...) -> String {
        let bundle = Bundle.main.path(forResource: language.rawValue, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .module
        let format = bundle.localizedString(forKey: key, value: key, table: "Localizable")
        return arguments.isEmpty ? format : String(format: format, locale: language.locale, arguments: arguments)
    }

    static func ui(_ english: String) -> String {
        string(english, language: .launchedLanguage)
    }
}

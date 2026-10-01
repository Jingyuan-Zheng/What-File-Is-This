import SwiftUI

struct SettingsView: View {
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.english.rawValue
    private var language: AppLanguage { AppLanguage(rawValue: appLanguageRaw) ?? .english }

    var body: some View {
        Form {
            Picker(L10n.string("settings.language", language: language), selection: $appLanguageRaw) {
                ForEach(AppLanguage.allCases) { option in
                    Text(verbatim: option.nativeName).tag(option.rawValue)
                }
            }
        }
        .formStyle(.grouped)
        .padding(16)
        .frame(width: 360)
        .onChange(of: appLanguageRaw) { _, newValue in
            guard let language = AppLanguage(rawValue: newValue) else { return }
            UserDefaults.standard.set([language.rawValue], forKey: "AppleLanguages")
        }
    }
}

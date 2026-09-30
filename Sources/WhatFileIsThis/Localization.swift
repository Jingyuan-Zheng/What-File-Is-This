import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var id: String { rawValue }
    var locale: Locale { Locale(identifier: rawValue) }
    var nativeName: String { self == .english ? "English" : "简体中文" }
}

enum L10n {
    static func string(_ key: String, language: AppLanguage, _ arguments: CVarArg...) -> String {
        let bundle = Bundle.main.path(forResource: language.rawValue, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .module
        let format = bundle.localizedString(forKey: key, value: key, table: "Localizable")
        return arguments.isEmpty ? format : String(format: format, locale: language.locale, arguments: arguments)
    }

    static func ui(_ chinese: String) -> String {
        guard AppLanguage(rawValue: UserDefaults.standard.string(forKey: "appLanguage") ?? "en") == .english else { return chinese }
        return [
            "正在分析文件…": "Analyzing file…", "结果准备好后会自动显示。": "The result will appear automatically when ready.",
            "这是什么": "What is this?", "属于": "Belongs to", "作用": "Purpose", "如何打开": "How to open", "可以删除吗": "Can it be deleted?", "来源": "Source", "可信度": "Confidence", "关键证据": "Key evidence",
            "复制结果": "Copy Result", "在访达中显示": "Show in Finder", "完成": "Done", "无法显示分析结果": "Unable to display analysis result", "关闭": "Close",
            "通过 Finder 中的 “What file is this” 快捷指令运行文件分析，结果会显示在这里。": "Run the “What file is this” Finder shortcut to analyze a file. Its result will appear here."
        ][chinese] ?? chinese
    }
}

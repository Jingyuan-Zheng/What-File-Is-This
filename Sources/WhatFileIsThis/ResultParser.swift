import Foundation

struct ResultParser {
    private static let headings = ["文件", "这是什么", "属于", "作用", "如何打开", "可以删除吗", "来源", "可信度", "证据"]

    static func parseResultFile(at url: URL) throws -> ParsedResultFile {
        guard let data = try? Data(contentsOf: url) else {
            throw ResultReadError.unreadable
        }

        if let text = String(data: data, encoding: .utf8) {
            if text.hasPrefix("WFITRESULT/1") {
                return try parseBridgeFormat(text)
            }

            if let parsed = try? parseJSON(data) {
                return parsed
            }

            if let parsed = try? parsePropertyList(data) {
                return parsed
            }

            let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else { throw ResultReadError.missingAnalysis }
            return ParsedResultFile(
                analysis: parseSectionedAnalysis(cleaned, targetPath: nil),
                deleteAfterOpen: false
            )
        }

        if let parsed = try? parsePropertyList(data) {
            return parsed
        }

        throw ResultReadError.invalidFormat
    }

    static func parseSectionedAnalysis(_ text: String, targetPath: String?) -> AnalysisResult {
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n").split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var sections: [String: [String]] = [:]
        var current: String?

        for originalLine in lines {
            let line = originalLine.trimmingCharacters(in: .whitespaces)
            if let match = splitHeading(line) {
                current = match.heading
                sections[match.heading, default: []].append(match.remainder)
            } else if let current {
                sections[current, default: []].append(originalLine)
            }
        }

        func body(_ key: String) -> String {
            let value = sections[key, default: []]
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return stripOuterMarkdown(value)
        }

        let targetName = targetPath.map { URL(fileURLWithPath: $0).lastPathComponent }
        let parsedName = body("文件")
        let fileName = !parsedName.isEmpty ? parsedName : (targetName ?? "文件分析结果")
        let what = body("这是什么")
        let evidence = parseEvidence(body("证据"))

        return AnalysisResult(
            fileName: fileName,
            what: what.isEmpty ? text.trimmingCharacters(in: .whitespacesAndNewlines) : what,
            belongsTo: body("属于"),
            purpose: body("作用"),
            openWith: body("如何打开").nilIfEmpty,
            deletion: body("可以删除吗"),
            source: body("来源"),
            confidence: body("可信度"),
            evidence: evidence,
            rawText: text.trimmingCharacters(in: .whitespacesAndNewlines),
            targetPath: targetPath
        )
    }

    private static func splitHeading(_ line: String) -> (heading: String, remainder: String)? {
        var candidate = line.trimmingCharacters(in: .whitespacesAndNewlines)
        candidate = candidate.replacingOccurrences(of: "**", with: "")

        for heading in headings {
            for separator in ["：", ":"] {
                let prefix = heading + separator
                if candidate.hasPrefix(prefix) {
                    let remainder = String(candidate.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                    return (heading, remainder)
                }
            }
        }
        return nil
    }

    private static func parseEvidence(_ text: String) -> [String] {
        guard !text.isEmpty else { return [] }
        var output: [String] = []
        var current: String?

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            let bulletPrefixes = ["- ", "• ", "* ", "– ", "— "]
            if let prefix = bulletPrefixes.first(where: { trimmed.hasPrefix($0) }) {
                if let current, !current.isEmpty { output.append(current) }
                current = String(trimmed.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            } else if var existing = current {
                existing += (existing.hasSuffix("\n") ? "" : " ") + trimmed
                current = existing
            } else {
                current = trimmed
            }
        }

        if let current, !current.isEmpty { output.append(current) }
        return output
    }

    private static func stripOuterMarkdown(_ value: String) -> String {
        var result = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.hasPrefix("**") && result.hasSuffix("**") && result.count >= 4 {
            result = String(result.dropFirst(2).dropLast(2))
        }
        return result
    }

    private static func parseBridgeFormat(_ text: String) throws -> ParsedResultFile {
        var values: [String: String] = [:]
        for line in text.split(separator: "\n", omittingEmptySubsequences: false).dropFirst() {
            guard let index = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<index])
            let value = String(line[line.index(after: index)...])
            values[key] = value
        }

        guard let resultB64 = values["RESULT_B64"],
              let resultData = Data(base64Encoded: resultB64),
              let analysisText = String(data: resultData, encoding: .utf8),
              !analysisText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ResultReadError.missingAnalysis
        }

        var targetPath: String?
        if let pathB64 = values["PATH_B64"],
           let pathData = Data(base64Encoded: pathB64),
           let path = String(data: pathData, encoding: .utf8),
           !path.isEmpty {
            targetPath = path
        }

        let deleteAfterOpen = values["DELETE_AFTER_OPEN"] == "1" || values["DELETE_AFTER_OPEN"]?.lowercased() == "true"
        return ParsedResultFile(
            analysis: parseSectionedAnalysis(analysisText, targetPath: targetPath),
            deleteAfterOpen: deleteAfterOpen
        )
    }

    private static func parseJSON(_ data: Data) throws -> ParsedResultFile {
        let object = try JSONSerialization.jsonObject(with: data)
        guard let dict = object as? [String: Any] else { throw ResultReadError.invalidFormat }
        return try parseDictionary(dict)
    }

    private static func parsePropertyList(_ data: Data) throws -> ParsedResultFile {
        var format = PropertyListSerialization.PropertyListFormat.xml
        let object = try PropertyListSerialization.propertyList(from: data, options: [], format: &format)
        guard let dict = object as? [String: Any] else { throw ResultReadError.invalidFormat }
        return try parseDictionary(dict)
    }

    private static func parseDictionary(_ dict: [String: Any]) throws -> ParsedResultFile {
        let targetPath = string(dict, keys: ["targetPath", "path", "filePath"])
        let deleteAfterOpen = bool(dict, keys: ["deleteAfterOpen", "temporary"]) ?? false

        if let analysisText = string(dict, keys: ["analysisText", "rawText", "result"]), !analysisText.isEmpty {
            return ParsedResultFile(
                analysis: parseSectionedAnalysis(analysisText, targetPath: targetPath),
                deleteAfterOpen: deleteAfterOpen
            )
        }

        let analysisDict = (dict["analysis"] as? [String: Any]) ?? dict
        let what = string(analysisDict, keys: ["what", "whatIsThis", "这是什么"]) ?? ""
        guard !what.isEmpty else { throw ResultReadError.missingAnalysis }

        let fileName = string(analysisDict, keys: ["file", "fileName", "文件"])
            ?? targetPath.map { URL(fileURLWithPath: $0).lastPathComponent }
            ?? "文件分析结果"
        let evidence = stringArray(analysisDict, keys: ["evidence", "证据"])

        let result = AnalysisResult(
            fileName: fileName,
            what: what,
            belongsTo: string(analysisDict, keys: ["belongsTo", "belongs", "属于"]) ?? "",
            purpose: string(analysisDict, keys: ["purpose", "role", "作用"]) ?? "",
            openWith: string(analysisDict, keys: ["openWith", "howToOpen", "如何打开"])?.nilIfEmpty,
            deletion: string(analysisDict, keys: ["deletion", "canDelete", "可以删除吗"]) ?? "",
            source: string(analysisDict, keys: ["source", "来源"]) ?? "",
            confidence: string(analysisDict, keys: ["confidence", "可信度"]) ?? "",
            evidence: evidence,
            rawText: string(analysisDict, keys: ["rawText"]) ?? buildRawText(from: analysisDict),
            targetPath: targetPath
        )
        return ParsedResultFile(analysis: result, deleteAfterOpen: deleteAfterOpen)
    }

    private static func string(_ dict: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = dict[key] as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        return nil
    }

    private static func bool(_ dict: [String: Any], keys: [String]) -> Bool? {
        for key in keys {
            if let value = dict[key] as? Bool { return value }
            if let value = dict[key] as? NSNumber { return value.boolValue }
            if let value = dict[key] as? String {
                if ["1", "true", "yes"].contains(value.lowercased()) { return true }
                if ["0", "false", "no"].contains(value.lowercased()) { return false }
            }
        }
        return nil
    }

    private static func stringArray(_ dict: [String: Any], keys: [String]) -> [String] {
        for key in keys {
            if let values = dict[key] as? [String] {
                return values.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            }
            if let value = dict[key] as? String {
                return parseEvidence(value)
            }
        }
        return []
    }

    private static func buildRawText(from dict: [String: Any]) -> String {
        let mapping: [(String, [String])] = [
            ("文件", ["file", "fileName", "文件"]),
            ("这是什么", ["what", "whatIsThis", "这是什么"]),
            ("属于", ["belongsTo", "belongs", "属于"]),
            ("作用", ["purpose", "role", "作用"]),
            ("如何打开", ["openWith", "howToOpen", "如何打开"]),
            ("可以删除吗", ["deletion", "canDelete", "可以删除吗"]),
            ("来源", ["source", "来源"]),
            ("可信度", ["confidence", "可信度"])
        ]
        var blocks: [String] = []
        for (heading, keys) in mapping {
            if let value = string(dict, keys: keys) {
                blocks.append("\(heading)：\n\(value)")
            }
        }
        let evidence = stringArray(dict, keys: ["evidence", "证据"])
        if !evidence.isEmpty {
            blocks.append("证据：\n" + evidence.map { "- \($0)" }.joined(separator: "\n"))
        }
        return blocks.joined(separator: "\n\n")
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

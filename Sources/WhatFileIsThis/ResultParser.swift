import Foundation

struct ResultParser {
    private enum Section: String, CaseIterable {
        case file = "[FILE]"
        case whatIsIt = "[WHAT_IS_IT]"
        case belongsTo = "[BELONGS_TO]"
        case purpose = "[PURPOSE]"
        case howToOpen = "[HOW_TO_OPEN]"
        case deleteGuidance = "[DELETE_GUIDANCE]"
        case source = "[SOURCE]"
        case confidence = "[CONFIDENCE]"
        case evidence = "[EVIDENCE]"
    }

    private static let legacyHeadingMap: [String: Section] = [
        "文件": .file,
        "这是什么": .whatIsIt,
        "属于": .belongsTo,
        "作用": .purpose,
        "如何打开": .howToOpen,
        "可以删除吗": .deleteGuidance,
        "来源": .source,
        "可信度": .confidence,
        "证据": .evidence
    ]

    /// Apple Intelligence can occasionally omit underscores from otherwise
    /// valid machine headings. Keep the result viewer resilient to those
    /// minor protocol variations instead of exposing the raw response.
    private static let headingAliases: [Section: [String]] = [
        .file: ["[FILENAME]"],
        .whatIsIt: ["[WHATISIT]", "[WHATISTHIS]"],
        .belongsTo: ["[BELONGSTO]"],
        .howToOpen: ["[HOWTOOPEN]"],
        .deleteGuidance: ["[DELETEGUIDANCE]"],
        .source: ["[WORKPUBLICATIONINFO]", "[CURRENTFILESOURCE]"],
        .confidence: [],
        .evidence: []
    ]

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
        var sections: [Section: [String]] = [:]
        var current: Section?

        for originalLine in lines {
            let line = originalLine.trimmingCharacters(in: .whitespaces)
            if let match = splitHeading(line) {
                current = match.heading
                sections[match.heading, default: []].append(match.remainder)
            } else if let current {
                sections[current, default: []].append(originalLine)
            }
        }

        func body(_ key: Section) -> String {
            let value = sections[key, default: []]
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return stripOuterMarkdown(value)
        }

        let targetName = targetPath.map { URL(fileURLWithPath: $0).lastPathComponent }
        let parsedName = body(.file)
        let fileName = !parsedName.isEmpty ? parsedName : (targetName ?? "File Analysis Result")
        let what = body(.whatIsIt)
        let evidence = parseEvidence(body(.evidence))
        let resolvedTargetPath = resolveTargetPath(
            explicitPath: targetPath,
            fileName: fileName,
            evidence: evidence
        )

        return AnalysisResult(
            fileName: fileName,
            what: what.isEmpty ? text.trimmingCharacters(in: .whitespacesAndNewlines) : what,
            belongsTo: body(.belongsTo),
            purpose: body(.purpose),
            openWith: body(.howToOpen).nilIfEmpty,
            deletion: body(.deleteGuidance),
            source: body(.source),
            confidence: body(.confidence),
            evidence: evidence,
            rawText: text.trimmingCharacters(in: .whitespacesAndNewlines),
            targetPath: resolvedTargetPath
        )
    }

    private static func splitHeading(_ line: String) -> (heading: Section, remainder: String)? {
        var candidate = line.trimmingCharacters(in: .whitespacesAndNewlines)
        candidate = candidate.replacingOccurrences(of: "**", with: "")

        // Canonical machine-readable format:
        // [FILE]
        // [WHAT_IS_IT]
        // ...
        for section in Section.allCases {
            let headings = [section.rawValue, section.rawValue.replacingOccurrences(of: "_", with: "")]
                + headingAliases[section, default: []]

            for heading in headings {
                if candidate == heading {
                    return (section, "")
                }

                // Also tolerate "[FILE]: value" and "[FILE] value".
                if candidate.hasPrefix(heading) {
                    let suffix = String(candidate.dropFirst(heading.count))
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    if suffix.hasPrefix(":") || suffix.hasPrefix("：") {
                        let remainder = String(suffix.dropFirst())
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        return (section, remainder)
                    }
                }
            }
        }

        // Backward compatibility with older localized outputs.
        for (legacyHeading, section) in legacyHeadingMap {
            for separator in ["：", ":"] {
                let prefix = legacyHeading + separator
                if candidate.hasPrefix(prefix) {
                    let remainder = String(candidate.dropFirst(prefix.count))
                        .trimmingCharacters(in: .whitespaces)
                    return (section, remainder)
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

            if let item = listItem(in: trimmed) {
                if let current, !current.isEmpty { output.append(current) }
                current = item
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

    private static func listItem(in line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let marker = trimmed.first, ["-", "*", "+", "•", "–", "—"].contains(marker) {
            let item = trimmed.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)
            return item.isEmpty ? nil : item
        }

        let digits = trimmed.prefix { $0.isNumber }
        guard !digits.isEmpty,
              let separator = trimmed.dropFirst(digits.count).first,
              [".", ")", "、"].contains(separator) else { return nil }
        let item = trimmed.dropFirst(digits.count + 1).trimmingCharacters(in: .whitespacesAndNewlines)
        return item.isEmpty ? nil : item
    }

    /// Older Shortcut results sometimes omit PATH_B64 but include the enclosing
    /// directory in evidence. Recover the selected item when it is unambiguous.
    private static func resolveTargetPath(explicitPath: String?, fileName: String, evidence: [String]) -> String? {
        if let explicitPath, !explicitPath.isEmpty { return explicitPath }

        for evidenceItem in evidence {
            guard let slash = evidenceItem.firstIndex(of: "/") else { continue }
            let candidate = String(evidenceItem[slash...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "。；;，,）)])\"'"))
            guard candidate.hasPrefix("/") else { continue }

            var url = URL(fileURLWithPath: candidate)
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else { continue }
            if isDirectory.boolValue {
                url.appendPathComponent(fileName)
            }
            if FileManager.default.fileExists(atPath: url.path) {
                return url.path
            }
        }
        return nil
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
        let what = string(analysisDict, keys: ["what", "whatIsThis"]) ?? ""
        guard !what.isEmpty else { throw ResultReadError.missingAnalysis }

        let fileName = string(analysisDict, keys: ["file", "fileName"])
            ?? targetPath.map { URL(fileURLWithPath: $0).lastPathComponent }
            ?? "File Analysis Result"
        let evidence = stringArray(analysisDict, keys: ["evidence"])

        let result = AnalysisResult(
            fileName: fileName,
            what: what,
            belongsTo: string(analysisDict, keys: ["belongsTo", "belongs"]) ?? "",
            purpose: string(analysisDict, keys: ["purpose", "role"]) ?? "",
            openWith: string(analysisDict, keys: ["openWith", "howToOpen"])?.nilIfEmpty,
            deletion: string(analysisDict, keys: ["deletion", "canDelete", "deleteGuidance"]) ?? "",
            source: string(analysisDict, keys: ["source"]) ?? "",
            confidence: string(analysisDict, keys: ["confidence"]) ?? "",
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
        let mapping: [(Section, [String])] = [
            (.file, ["file", "fileName"]),
            (.whatIsIt, ["what", "whatIsThis"]),
            (.belongsTo, ["belongsTo", "belongs"]),
            (.purpose, ["purpose", "role"]),
            (.howToOpen, ["openWith", "howToOpen"]),
            (.deleteGuidance, ["deletion", "canDelete", "deleteGuidance"]),
            (.source, ["source"]),
            (.confidence, ["confidence"])
        ]

        var blocks: [String] = []
        for (section, keys) in mapping {
            if let value = string(dict, keys: keys) {
                blocks.append("\(section.rawValue)\n\(value)")
            }
        }

        let evidence = stringArray(dict, keys: ["evidence"])
        if !evidence.isEmpty {
            blocks.append(
                "\(Section.evidence.rawValue)\n" +
                evidence.map { "- \($0)" }.joined(separator: "\n")
            )
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

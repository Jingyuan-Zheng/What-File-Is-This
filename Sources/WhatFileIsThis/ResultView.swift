import AppKit
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: ResultStore

    var body: some View {
        Group {
            if let analysis = store.analysis {
                AnalysisView(analysis: analysis)
            } else if let error = store.errorMessage {
                ErrorView(message: error)
            } else {
                EmptyViewState()
            }
        }
    }
}

private struct AnalysisView: View {
    @EnvironmentObject private var store: ResultStore
    let analysis: AnalysisResult

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(analysis: analysis)
                .padding(.horizontal, 24)
                .padding(.top, 40)
                .padding(.bottom, 16)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 26) {
                    AnalysisSection(
                        symbol: "doc.text.magnifyingglass",
                        title: "这是什么",
                        content: analysis.what
                    )

                    if !analysis.belongsTo.isEmpty {
                        AnalysisSection(
                            symbol: "shippingbox",
                            title: "属于",
                            content: analysis.belongsTo
                        )
                    }

                    if !analysis.purpose.isEmpty {
                        AnalysisSection(
                            symbol: "gearshape.2",
                            title: "作用",
                            content: analysis.purpose
                        )
                    }

                    if let openWith = analysis.openWith, !openWith.isEmpty {
                        AnalysisSection(
                            symbol: "arrow.up.forward.app",
                            title: "如何打开",
                            content: openWith
                        )
                    }

                    if !analysis.deletion.isEmpty {
                        AnalysisSection(
                            symbol: deletionSymbol(for: analysis.deletion),
                            title: "可以删除吗",
                            content: analysis.deletion
                        )
                    }

                    if !analysis.source.isEmpty {
                        AnalysisSection(
                            symbol: "globe",
                            title: "来源",
                            content: analysis.source
                        )
                    }

                    if !analysis.confidence.isEmpty {
                        AnalysisSection(
                            symbol: "checkmark.shield",
                            title: "可信度",
                            content: analysis.confidence
                        )
                    }

                    if !analysis.evidence.isEmpty {
                        EvidenceSection(evidence: analysis.evidence)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            FooterView(analysis: analysis)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(.bar)
        }
        .background(.regularMaterial)
    }

    private func deletionSymbol(for text: String) -> String {
        if text.contains("不建议删除") { return "trash.slash" }
        if text.contains("无法可靠判断") { return "questionmark.circle" }
        return "trash"
    }
}

private struct HeaderView: View {
    let analysis: AnalysisResult

    private var metadata: FileMetadata? {
        FileMetadata(url: analysis.targetURL)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            FileIcon(path: analysis.targetPath)

            VStack(alignment: .leading, spacing: 8) {
                Text(analysis.fileName)
                    .font(.title.weight(.semibold))
                    .lineLimit(2)
                    .textSelection(.enabled)

                FileMetadataView(directory: metadata?.displayDirectory, metadata: metadata)
            }

            Spacer(minLength: 10)

            if !analysis.confidence.isEmpty {
                Text(analysis.confidence)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(.quaternary, in: Capsule())
            }
        }
    }
}

private struct FileIcon: View {
    let path: String?

    var body: some View {
        Image(nsImage: icon)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: 76, height: 76)
            .accessibilityHidden(true)
    }

    private var icon: NSImage {
        if let path, FileManager.default.fileExists(atPath: path) {
            let image = NSWorkspace.shared.icon(forFile: path)
            image.size = NSSize(width: 64, height: 64)
            return image
        }
        return NSImage(systemSymbolName: "doc.text.magnifyingglass", accessibilityDescription: "文件") ?? NSImage()
    }
}

private struct FileMetadata {
    let directory: String?
    let modifiedDate: Date?
    let fileSize: Int?

    var displayDirectory: String? {
        guard let directory else { return nil }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if directory == home { return "~" }
        if directory.hasPrefix(home + "/") {
            return "~" + String(directory.dropFirst(home.count))
        }
        return directory
    }

    init?(url: URL?) {
        guard let url else { return nil }
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        directory = url.deletingLastPathComponent().path
        modifiedDate = values?.contentModificationDate
        fileSize = values?.fileSize
    }
}

private struct FileMetadataView: View {
    let directory: String?
    let metadata: FileMetadata?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let directory {
                Label(directory, systemImage: "folder")
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }

            HStack(spacing: 12) {
                if let modifiedDate = metadata?.modifiedDate {
                    Label {
                        Text(modifiedDate, format: .dateTime.year().month().day().hour().minute())
                    } icon: {
                        Image(systemName: "clock")
                    }
                }

                if let fileSize = metadata?.fileSize {
                    Label(ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file), systemImage: "internaldrive")
                }
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

private struct AnalysisSection: View {
    let symbol: String
    let title: String
    let content: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 20, height: 20)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 7) {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)

                SectionContent(content: content)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SectionContent: View {
    let content: String

    private var listItems: [String] {
        content
            .split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap(markdownListItem)
    }

    private func markdownListItem(_ line: Substring) -> String? {
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

    var body: some View {
        if listItems.isEmpty {
            Text(content)
                .font(.body)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            VStack(alignment: .leading, spacing: 7) {
                ForEach(Array(listItems.enumerated()), id: \.offset) { _, item in
                    Label(item, systemImage: "checkmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(.primary)
                        .labelStyle(.titleAndIcon)
                        .symbolRenderingMode(.hierarchical)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct EvidenceSection: View {
    let evidence: [String]

    private var items: [String] {
        evidence.flatMap { evidenceItem in
            evidenceItem
                .split(whereSeparator: { "。；\n".contains($0) })
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 20, height: 20)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 9) {
                Text("关键证据")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 20, height: 20)
                            .background(.quaternary, in: Circle())
                        Text(item)
                            .font(.body)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct FooterView: View {
    @EnvironmentObject private var store: ResultStore
    let analysis: AnalysisResult

    private var canReveal: Bool {
        guard let url = analysis.targetURL else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    var body: some View {
        HStack(spacing: 10) {
            Button {
                store.copyResult()
            } label: {
                Label("复制结果", systemImage: "doc.on.doc")
            }

            Spacer()

            if canReveal {
                Button {
                    store.revealInFinder()
                } label: {
                    Label("在访达中显示", systemImage: "folder")
                }
            }

            Button {
                store.closeWindow()
            } label: {
                Label("完成", systemImage: "checkmark")
            }
            .keyboardShortcut(.defaultAction)
        }
    }
}

private struct EmptyViewState: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 46, weight: .regular))
                .foregroundStyle(.secondary)

            Text("What File Is This")
                .font(.title2.weight(.semibold))

            Text("通过 Finder 中的 “What file is this” 快捷指令运行文件分析，结果会显示在这里。")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 430)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

private struct ErrorView: View {
    @EnvironmentObject private var store: ResultStore
    let message: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("无法显示分析结果")
                .font(.title3.weight(.semibold))
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .textSelection(.enabled)
            Button("关闭") {
                store.closeWindow()
            }
            .keyboardShortcut(.defaultAction)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

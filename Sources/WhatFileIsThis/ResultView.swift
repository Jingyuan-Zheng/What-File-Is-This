import AppKit
import SwiftUI

struct RootView: View {
    let document: ResultDocument

    var body: some View {
        Group {
            if let analysis = document.parsedResult?.analysis {
                AnalysisView(
                    analysis: analysis,
                    onCopy: copyResult,
                    onRevealInFinder: revealInFinder,
                    onClose: closeWindow
                )
            } else {
                LoadingView()
            }
        }
    }

    private func copyResult() {
        guard let analysis = document.parsedResult?.analysis else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(analysis.rawText, forType: .string)
    }

    private func revealInFinder() {
        guard let url = document.parsedResult?.analysis.targetURL,
              FileManager.default.fileExists(atPath: url.path) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func closeWindow() {
        NSApplication.shared.keyWindow?.performClose(nil)
    }
}

struct ResultDocumentView: View {
    let document: ResultDocument

    var body: some View {
        RootView(document: document)
    }
}

private struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text(L10n.ui("Analyzing file…"))
                .font(.title3.weight(.semibold))
            Text(L10n.ui("The result will appear automatically when ready."))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
    }
}

private struct AnalysisView: View {
    let analysis: AnalysisResult
    let onCopy: () -> Void
    let onRevealInFinder: () -> Void
    let onClose: () -> Void

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
                        title: L10n.ui("What is this?"),
                        content: analysis.what
                    )

                    if !analysis.belongsTo.isEmpty {
                        AnalysisSection(
                            symbol: "shippingbox",
                            title: L10n.ui("Belongs to"),
                            content: analysis.belongsTo
                        )
                    }

                    if !analysis.purpose.isEmpty {
                        AnalysisSection(
                            symbol: "gearshape.2",
                            title: L10n.ui("Purpose"),
                            content: analysis.purpose
                        )
                    }

                    if let openWith = analysis.openWith, !openWith.isEmpty {
                        AnalysisSection(
                            symbol: "arrow.up.forward.app",
                            title: L10n.ui("How to open"),
                            content: openWith
                        )
                    }

                    if !analysis.deletion.isEmpty {
                        AnalysisSection(
                            symbol: deletionSymbol(for: analysis.deletion),
                            title: L10n.ui("Can it be deleted?"),
                            content: analysis.deletion
                        )
                    }

                    if !analysis.source.isEmpty {
                        AnalysisSection(
                            symbol: "globe",
                            title: L10n.ui("Source"),
                            content: analysis.source
                        )
                    }

                    if !analysis.confidence.isEmpty {
                        AnalysisSection(
                            symbol: "checkmark.shield",
                            title: L10n.ui("Confidence"),
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

            FooterView(
                analysis: analysis,
                onCopy: onCopy,
                onRevealInFinder: onRevealInFinder,
                onClose: onClose
            )
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
        }
        .background(.regularMaterial)
    }

    private func deletionSymbol(for text: String) -> String {
        let normalized = text.lowercased()
        if normalized.contains("do not delete") || normalized.contains("not recommended to delete") || text.contains("不建议删除") {
            return "trash.slash"
        }
        if normalized.contains("cannot reliably determine") || normalized.contains("unable to determine reliably") || text.contains("无法可靠判断") {
            return "questionmark.circle"
        }
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
        return NSImage(systemSymbolName: "doc.text.magnifyingglass", accessibilityDescription: L10n.ui("File")) ?? NSImage()
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
            MarkdownText(content)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            VStack(alignment: .leading, spacing: 7) {
                ForEach(Array(listItems.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                        MarkdownText(item)
                            .textSelection(.enabled)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

/// Renders the Markdown bold delimiter as a readable highlighter instead of
/// exposing the asterisks in analysis prose.
private struct MarkdownText: View {
    let source: String
    @Environment(\.colorScheme) private var colorScheme

    init(_ source: String) {
        self.source = source
    }

    var body: some View {
        Text(attributedText)
            .font(.body)
            .foregroundStyle(.primary)
    }

    private var attributedText: AttributedString {
        var output = AttributedString()
        var remaining = source[...]

        while let opening = remaining.range(of: "**") {
            output += AttributedString(String(remaining[..<opening.lowerBound]))
            let afterOpening = remaining[opening.upperBound...]

            guard let closing = afterOpening.range(of: "**") else {
                output += AttributedString(String(remaining[opening.lowerBound...]))
                return output
            }

            let markedText = String(afterOpening[..<closing.lowerBound])
            var marked = AttributedString(markedText)
            marked.inlinePresentationIntent = .stronglyEmphasized
            marked.backgroundColor = NSColor.systemYellow.withAlphaComponent(
                colorScheme == .dark ? 0.46 : 0.32
            )
            output += marked
            remaining = afterOpening[closing.upperBound...]
        }

        output += AttributedString(String(remaining))
        return output
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
                Text(L10n.ui("Key evidence"))
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 20, height: 20)
                            .background(.quaternary, in: Circle())
                        MarkdownText(item)
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
    let analysis: AnalysisResult
    let onCopy: () -> Void
    let onRevealInFinder: () -> Void
    let onClose: () -> Void

    private var canReveal: Bool {
        guard let url = analysis.targetURL else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    var body: some View {
        HStack(spacing: 10) {
            Button {
                onCopy()
            } label: {
                Label(L10n.ui("Copy Result"), systemImage: "doc.on.doc")
            }

            Spacer()

            if canReveal {
                Button {
                    onRevealInFinder()
                } label: {
                    Label(L10n.ui("Show in Finder"), systemImage: "folder")
                }
            }

            Button {
                onClose()
            } label: {
                Label(L10n.ui("Done"), systemImage: "checkmark")
            }
            .keyboardShortcut(.defaultAction)
        }
    }
}

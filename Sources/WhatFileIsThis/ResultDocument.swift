import Foundation
import Observation
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let whatFileIsThisResult = UTType(exportedAs: "dev.is-a.zjy.wfitresult", conformingTo: .data)
}

/// A result file is a real macOS document: each URL supplied to the app gets
/// an independent document instance and therefore an independent window.
@Observable
final class ResultDocument: ReadableDocument {
    static let readableContentTypes: [UTType] = [.whatFileIsThisResult]

    private(set) var parsedResult: ParsedResultFile?
    private let fileURL: URL?
    private var pollingTask: Task<Void, Never>?

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL
    }

    func reader(configuration: ReadConfiguration) -> FileWrapperDocumentReader<ParsedResultFile> {
        FileWrapperDocumentReader(configuration) { fileWrapper in
            guard let data = fileWrapper.regularFileContents else {
                throw ResultReadError.unreadable
            }
            return try ResultParser.parseResultData(data)
        }
    }

    @MainActor
    func apply(snapshot: ParsedResultFile, previous: ParsedResultFile?) async throws {
        parsedResult = snapshot
        pollingTask?.cancel()
        pollingTask = nil

        guard snapshot.isLoading, let fileURL else { return }

        // The Shortcut atomically replaces this per-run bridge file when the
        // model returns. Keep this document's existing system window and swap
        // only its model; no focus, level, or frame manipulation is involved.
        pollingTask = Task { [weak self, fileURL] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled else { return }
                guard let updated = try? ResultParser.parseResultFile(at: fileURL),
                      !updated.isLoading else { continue }
                try? await self?.apply(snapshot: updated, previous: self?.parsedResult)
                return
            }
        }
    }

    deinit {
        pollingTask?.cancel()
    }
}

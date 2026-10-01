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
    }
}

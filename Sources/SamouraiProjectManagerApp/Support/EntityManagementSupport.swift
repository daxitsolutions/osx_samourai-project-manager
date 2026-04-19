import SwiftUI
import UniformTypeIdentifiers

struct EntityCSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText, .plainText] }
    let data: Data

    init(text: String) {
        self.data = Data(text.utf8)
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

enum EntityCSVBuilder {
    static func build(headers: [String], rows: [[String]]) -> String {
        let escapedHeaders = headers.map(csvEscape).joined(separator: ",")
        let escapedRows = rows.map { row in
            row.map(csvEscape).joined(separator: ",")
        }
        return ([escapedHeaders] + escapedRows).joined(separator: "\n")
    }

    private static func csvEscape(_ raw: String) -> String {
        let needsQuotes = raw.contains(",") || raw.contains("\"") || raw.contains("\n")
        let escaped = raw.replacingOccurrences(of: "\"", with: "\"\"")
        return needsQuotes ? "\"\(escaped)\"" : escaped
    }
}

extension Set where Element == UUID {
    var singleSelection: UUID? {
        count == 1 ? first : nil
    }
}

import Foundation

struct ClipboardEntry: Identifiable, Codable {
    let id: UUID
    let content: String
    let sourceApp: String?
    let timestamp: Date
    let type: EntryType
    var isPinned: Bool
    var isRedacted: Bool

    enum EntryType: String, Codable {
        case code, url, email, path, color, plain
    }

    static let redactedContent = "[REDACTED - possible secret]"
}

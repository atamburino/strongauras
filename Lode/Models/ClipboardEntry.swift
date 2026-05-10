import Foundation

struct ClipboardEntry: Identifiable {
    let id: UUID
    let contentType: ContentType
    let contentBlob: Data
    let previewText: String
    let capturedAt: Date
    let sourceAppBundleId: String?

    enum ContentType: String {
        case plainText = "text/plain"
        case richText  = "text/rtf"
        case image     = "image/png"
    }

    var isImage: Bool { contentType == .image }
}

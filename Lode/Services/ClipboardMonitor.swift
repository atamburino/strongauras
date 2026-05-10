import AppKit
import Foundation
import os.log

private let log = OSLog(subsystem: "com.stone.lode", category: "ClipboardMonitor")

// Bundle IDs of password managers — never capture their clipboard writes
private let blockedBundleIDs: Set<String> = [
    "com.1password.1password",
    "com.bitwarden.desktop",
    "com.apple.keychainaccess",
]

class ClipboardMonitor {
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private let db: DatabaseManager

    init(db: DatabaseManager = .shared) {
        self.db = db
    }

    func start() {
        lastChangeCount = NSPasteboard.general.changeCount
        // 250ms interval per PRD §4.2
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        let current = NSPasteboard.general.changeCount
        guard current != lastChangeCount else { return }
        lastChangeCount = current

        let frontmost = NSWorkspace.shared.frontmostApplication
        let bundleId = frontmost?.bundleIdentifier

        // Skip password managers
        if let bundleId, blockedBundleIDs.contains(bundleId) { return }

        let pasteboard = NSPasteboard.general

        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            capture(
                blob: Data(text.utf8),
                preview: String(text.prefix(200)),
                type: .plainText,
                bundleId: bundleId
            )
        } else if let rtfData = pasteboard.data(forType: .rtf) {
            let preview = NSAttributedString(rtf: rtfData, documentAttributes: nil)
                .string
                .prefix(200)
                .description
            capture(blob: rtfData, preview: preview, type: .richText, bundleId: bundleId)
        } else if let tiff = pasteboard.data(forType: .tiff),
                  let image = NSImage(data: tiff),
                  let png = pngData(from: image) {
            let dims = "\(Int(image.size.width))×\(Int(image.size.height))"
            capture(blob: png, preview: "[Image \(dims)]", type: .image, bundleId: bundleId)
        }
    }

    private func capture(blob: Data, preview: String, type: ClipboardEntry.ContentType, bundleId: String?) {
        let entry = ClipboardEntry(
            id: UUID(),
            contentType: type,
            contentBlob: blob,
            previewText: preview,
            capturedAt: Date(),
            sourceAppBundleId: bundleId
        )
        db.insert(entry: entry)
        // Log only metadata — never content — even in DEBUG
        os_log("Captured entry type=%{public}s source=%{public}s",
               log: log, type: .debug, type.rawValue, bundleId ?? "unknown")
    }

    private func pngData(from image: NSImage) -> Data? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        return rep.representation(using: .png, properties: [:])
    }
}

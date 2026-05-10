import AppKit
import Foundation

class ClipboardMonitor {
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private let db: DatabaseManager
    private let redactor: SecretRedactor

    init(db: DatabaseManager = .shared, redactor: SecretRedactor = .init()) {
        self.db = db
        self.redactor = redactor
    }

    func start() {
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
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

        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else { return }

        let sourceApp = NSWorkspace.shared.frontmostApplication?.localizedName
        let (finalContent, isRedacted) = redactor.process(text)

        let entry = ClipboardEntry(
            id: UUID(),
            content: finalContent,
            sourceApp: sourceApp,
            timestamp: Date(),
            type: .plain,   // TODO: classify in Phase 3
            isPinned: false,
            isRedacted: isRedacted
        )

        db.insert(entry: entry)
    }
}

import Foundation
import SQLite3

// NOTE for Xcode setup: link SQLCipher instead of system SQLite3 for at-rest encryption.
// Replace `import SQLite3` with the SQLCipher module and open with sqlite3_key().
// See PRD §5 — encryption is a hard requirement before shipping.

class DatabaseManager {
    static let shared = DatabaseManager()

    private var db: OpaquePointer?

    var maxEntries: Int {
        UserDefaults.standard.integer(forKey: "historyDepth").nonzero(default: 50)
    }

    private init() {
        openDatabase()
        createTable()
    }

    // MARK: - Setup

    private func openDatabase() {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Lode")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("clipboard.db")
        sqlite3_open(url.path, &db)
    }

    private func createTable() {
        let sql = """
        CREATE TABLE IF NOT EXISTS clipboard_entries (
            id                  TEXT PRIMARY KEY,
            content_type        TEXT NOT NULL,
            content_blob        BLOB NOT NULL,
            preview_text        TEXT NOT NULL,
            captured_at         REAL NOT NULL,
            source_app_bundle_id TEXT
        );
        """
        sqlite3_exec(db, sql, nil, nil, nil)
    }

    // MARK: - Write

    func insert(entry: ClipboardEntry) {
        let sql = """
        INSERT INTO clipboard_entries
            (id, content_type, content_blob, preview_text, captured_at, source_app_bundle_id)
        VALUES (?, ?, ?, ?, ?, ?);
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }

        let blob = entry.contentBlob as NSData
        sqlite3_bind_text(stmt, 1, entry.id.uuidString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, entry.contentType.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_blob(stmt, 3, blob.bytes, Int32(blob.length), SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 4, entry.previewText, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(stmt, 5, entry.capturedAt.timeIntervalSince1970)
        sqlite3_bind_text(stmt, 6, entry.sourceAppBundleId ?? "", -1, SQLITE_TRANSIENT)

        sqlite3_step(stmt)
        evictIfNeeded()
    }

    func delete(id: UUID) {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "DELETE FROM clipboard_entries WHERE id = ?;", -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, id.uuidString, -1, SQLITE_TRANSIENT)
        sqlite3_step(stmt)
    }

    func clearAll() {
        sqlite3_exec(db, "DELETE FROM clipboard_entries;", nil, nil, nil)
    }

    // MARK: - Read

    func fetchAll() -> [ClipboardEntry] {
        let sql = """
        SELECT id, content_type, content_blob, preview_text, captured_at, source_app_bundle_id
        FROM clipboard_entries
        ORDER BY captured_at DESC
        LIMIT ?;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int(stmt, 1, Int32(maxEntries))

        var entries: [ClipboardEntry] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard
                let rawId   = sqlite3_column_text(stmt, 0),
                let rawType = sqlite3_column_text(stmt, 1),
                let rawBlob = sqlite3_column_blob(stmt, 2),
                let rawPrev = sqlite3_column_text(stmt, 3),
                let id      = UUID(uuidString: String(cString: rawId)),
                let type    = ClipboardEntry.ContentType(rawValue: String(cString: rawType))
            else { continue }

            let blobLen  = sqlite3_column_bytes(stmt, 2)
            let blob     = Data(bytes: rawBlob, count: Int(blobLen))
            let preview  = String(cString: rawPrev)
            let ts       = sqlite3_column_double(stmt, 4)
            let bundleId = sqlite3_column_text(stmt, 5).map { String(cString: $0) }

            entries.append(ClipboardEntry(
                id: id,
                contentType: type,
                contentBlob: blob,
                previewText: preview,
                capturedAt: Date(timeIntervalSince1970: ts),
                sourceAppBundleId: bundleId?.isEmpty == true ? nil : bundleId
            ))
        }
        return entries
    }

    // MARK: - Eviction

    private func evictIfNeeded() {
        let sql = """
        DELETE FROM clipboard_entries
        WHERE id NOT IN (
            SELECT id FROM clipboard_entries ORDER BY captured_at DESC LIMIT ?
        );
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(maxEntries))
        sqlite3_step(stmt)
    }
}

// Avoid capturing C function pointer literal type as SQLITE_TRANSIENT in older SDKs
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

private extension Int {
    func nonzero(default fallback: Int) -> Int { self == 0 ? fallback : self }
}

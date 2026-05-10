import Foundation
import SQLite3

class DatabaseManager {
    static let shared = DatabaseManager()

    private var db: OpaquePointer?
    private let maxEntries: Int

    private init() {
        // Read from UserDefaults; default 50
        maxEntries = UserDefaults.standard.integer(forKey: "historyDepth").nonzero(default: 50)
        openDatabase()
        createTable()
    }

    private func openDatabase() {
        let url = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Lode/clipboard.sqlite")
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                  withIntermediateDirectories: true)
        sqlite3_open(url.path, &db)
    }

    private func createTable() {
        let sql = """
        CREATE TABLE IF NOT EXISTS clipboard_entries (
            id TEXT PRIMARY KEY,
            content TEXT NOT NULL,
            source_app TEXT,
            timestamp REAL NOT NULL,
            type TEXT NOT NULL,
            is_pinned INTEGER NOT NULL DEFAULT 0,
            is_redacted INTEGER NOT NULL DEFAULT 0
        );
        """
        sqlite3_exec(db, sql, nil, nil, nil)
    }

    func insert(entry: ClipboardEntry) {
        let sql = """
        INSERT INTO clipboard_entries (id, content, source_app, timestamp, type, is_pinned, is_redacted)
        VALUES (?, ?, ?, ?, ?, ?, ?);
        """
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        sqlite3_bind_text(stmt, 1, entry.id.uuidString, -1, nil)
        sqlite3_bind_text(stmt, 2, entry.content, -1, nil)
        sqlite3_bind_text(stmt, 3, entry.sourceApp ?? "", -1, nil)
        sqlite3_bind_double(stmt, 4, entry.timestamp.timeIntervalSince1970)
        sqlite3_bind_text(stmt, 5, entry.type.rawValue, -1, nil)
        sqlite3_bind_int(stmt, 6, entry.isPinned ? 1 : 0)
        sqlite3_bind_int(stmt, 7, entry.isRedacted ? 1 : 0)
        sqlite3_step(stmt)
        sqlite3_finalize(stmt)

        evictIfNeeded()
    }

    func fetchAll() -> [ClipboardEntry] {
        var entries: [ClipboardEntry] = []
        let sql = "SELECT * FROM clipboard_entries ORDER BY timestamp DESC LIMIT ?;"
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        sqlite3_bind_int(stmt, 1, Int32(maxEntries))
        while sqlite3_step(stmt) == SQLITE_ROW {
            // TODO: map columns to ClipboardEntry
        }
        sqlite3_finalize(stmt)
        return entries
    }

    func clearAll() {
        sqlite3_exec(db, "DELETE FROM clipboard_entries WHERE is_pinned = 0;", nil, nil, nil)
    }

    private func evictIfNeeded() {
        let sql = """
        DELETE FROM clipboard_entries
        WHERE is_pinned = 0
        AND id NOT IN (
            SELECT id FROM clipboard_entries ORDER BY timestamp DESC LIMIT ?
        );
        """
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        sqlite3_bind_int(stmt, 1, Int32(maxEntries))
        sqlite3_step(stmt)
        sqlite3_finalize(stmt)
    }
}

private extension Int {
    func nonzero(default fallback: Int) -> Int { self == 0 ? fallback : self }
}

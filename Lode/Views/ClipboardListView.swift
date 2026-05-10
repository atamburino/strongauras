import SwiftUI

struct ClipboardListView: View {
    @State private var entries: [ClipboardEntry] = []
    @State private var searchText = ""
    @State private var expandedID: UUID?

    private var filtered: [ClipboardEntry] {
        guard !searchText.isEmpty else { return entries }
        return entries.filter { $0.content.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            SearchBar(text: $searchText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filtered) { entry in
                        ClipboardRowView(
                            entry: entry,
                            isExpanded: expandedID == entry.id,
                            onTap: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    expandedID = expandedID == entry.id ? nil : entry.id
                                }
                            },
                            onCopy: { copyToClipboard(entry) }
                        )
                        Divider().padding(.leading, 12)
                    }
                }
            }
        }
        .onAppear { entries = DatabaseManager.shared.fetchAll() }
    }

    private func copyToClipboard(_ entry: ClipboardEntry) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.content, forType: .string)
    }
}

struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search", text: $text)
                .textFieldStyle(.plain)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct ClipboardRowView: View {
    let entry: ClipboardEntry
    let isExpanded: Bool
    let onTap: () -> Void
    let onCopy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if entry.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                Text(entry.isRedacted ? ClipboardEntry.redactedContent : entry.content)
                    .lineLimit(isExpanded ? nil : 2)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(entry.isRedacted ? .secondary : .primary)
                Spacer()
            }

            if isExpanded {
                HStack {
                    if let source = entry.sourceApp {
                        Label(source, systemImage: "app")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text(entry.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Copy", action: onCopy)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.mini)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

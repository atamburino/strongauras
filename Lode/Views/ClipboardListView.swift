import SwiftUI
import AppKit

struct ClipboardListView: View {
    @Binding var isExpanded: Bool
    @State private var entries: [ClipboardEntry] = []
    @State private var searchText = ""
    @State private var selectedIndex: Int = 0
    @State private var expandedID: UUID?
    @FocusState private var searchFocused: Bool

    private var filtered: [ClipboardEntry] {
        guard !searchText.isEmpty else { return entries }
        return entries.filter {
            $0.previewText.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            SearchBar(text: $searchText, isFocused: $searchFocused)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { idx, entry in
                            ClipboardRowView(
                                entry: entry,
                                isSelected: idx == selectedIndex,
                                isExpanded: expandedID == entry.id,
                                onTap: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        expandedID = expandedID == entry.id ? nil : entry.id
                                    }
                                    selectedIndex = idx
                                },
                                onCopy: { pasteAndCollapse(entry) }
                            )
                            .id(idx)
                            Divider().padding(.leading, 12)
                        }
                        if filtered.isEmpty {
                            Text("No matches")
                                .foregroundStyle(.secondary)
                                .padding(32)
                        }
                    }
                }
                .onChange(of: selectedIndex) { _, idx in
                    withAnimation { proxy.scrollTo(idx, anchor: .center) }
                }
            }
        }
        .onAppear {
            entries = DatabaseManager.shared.fetchAll()
            selectedIndex = 0
            searchFocused = true
        }
        .onKeyPress(.escape) {
            if !searchText.isEmpty {
                searchText = ""
                return .handled
            }
            isExpanded = false
            return .handled
        }
        // j / ↓  — move down
        .onKeyPress("j")  { moveSelection(by: +1); return .handled }
        .onKeyPress(.downArrow) { moveSelection(by: +1); return .handled }
        // k / ↑  — move up
        .onKeyPress("k")  { moveSelection(by: -1); return .handled }
        .onKeyPress(.upArrow)   { moveSelection(by: -1); return .handled }
        // Enter — copy + collapse
        .onKeyPress(.return) {
            if let entry = filtered[safe: selectedIndex] {
                pasteAndCollapse(entry)
            }
            return .handled
        }
        // d — delete selected (no confirmation per PRD §4.2)
        .onKeyPress("d") {
            deleteSelected()
            return .handled
        }
        // /  — focus search
        .onKeyPress("/") {
            searchFocused = true
            return .handled
        }
        // 1–9 quick-select
        .onKeyPress(characters: .decimalDigits, phases: .down) { press in
            if let n = press.characters.first?.wholeNumberValue, n >= 1, n <= 9 {
                selectedIndex = min(n - 1, filtered.count - 1)
            }
            return .handled
        }
    }

    // MARK: - Actions

    private func moveSelection(by delta: Int) {
        guard !filtered.isEmpty else { return }
        selectedIndex = (selectedIndex + delta + filtered.count) % filtered.count
    }

    private func pasteAndCollapse(_ entry: ClipboardEntry) {
        if entry.contentType == .image, let image = NSImage(data: entry.contentBlob) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects([image])
        } else if let text = String(data: entry.contentBlob, encoding: .utf8) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
        isExpanded = false
    }

    private func deleteSelected() {
        guard let entry = filtered[safe: selectedIndex] else { return }
        DatabaseManager.shared.delete(id: entry.id)
        entries = DatabaseManager.shared.fetchAll()
        selectedIndex = min(selectedIndex, max(0, filtered.count - 1))
    }
}

// MARK: - Search bar

struct SearchBar: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.caption)
            TextField("Search", text: $text)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .monospaced))
                .focused(isFocused)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Row

struct ClipboardRowView: View {
    let entry: ClipboardEntry
    let isSelected: Bool
    let isExpanded: Bool
    let onTap: () -> Void
    let onCopy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                if entry.isImage {
                    thumbnailView
                } else {
                    Text(entry.previewText)
                        .lineLimit(isExpanded ? nil : 2)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.primary)
                }
                Spacer()
                Text(entry.capturedAt.relativeString)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if isExpanded {
                HStack {
                    if let bundleId = entry.sourceAppBundleId,
                       let appName = appName(for: bundleId) {
                        Label(appName, systemImage: "app")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text(entry.capturedAt.formatted(date: .abbreviated, time: .shortened))
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
        .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let image = NSImage(data: entry.contentBlob) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 60)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }

    private func appName(for bundleId: String) -> String? {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
            .first?.localizedName
        ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId)
            .flatMap { Bundle(url: $0)?.infoDictionary?["CFBundleDisplayName"] as? String }
    }
}

// MARK: - Helpers

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private extension Date {
    var relativeString: String {
        let diff = Date().timeIntervalSince(self)
        switch diff {
        case ..<60:         return "just now"
        case ..<3600:       return "\(Int(diff / 60))m ago"
        case ..<86400:      return "\(Int(diff / 3600))h ago"
        default:            return "\(Int(diff / 86400))d ago"
        }
    }
}

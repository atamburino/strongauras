import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("historyDepth") private var historyDepth = 50
    @AppStorage("launchAtLogin") private var launchAtLogin = false

    // Phase 2 stubs — stored now, UI exposed later
    @AppStorage("enableSoundNotifications") private var enableSoundNotifications = false
    @AppStorage("enableRedaction") private var enableRedaction = true

    private let depthOptions = [10, 50, 100, 200]

    var body: some View {
        Form {
            Section("Clipboard") {
                Picker("History depth", selection: $historyDepth) {
                    ForEach(depthOptions, id: \.self) { n in
                        Text("\(n) entries").tag(n)
                    }
                }

                Button("Clear clipboard history", role: .destructive) {
                    DatabaseManager.shared.clearAll()
                }

                Button("Open data folder") {
                    let url = FileManager.default
                        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                        .appendingPathComponent("Lode")
                    NSWorkspace.shared.open(url)
                }
            }

            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        // SMAppService requires macOS 13+; target is 14+ so this is safe
                        let service = SMAppService.mainApp
                        try? enabled ? service.register() : service.unregister()
                    }
            }

            // Phase 2 — settings model stubbed here, UI withheld
            // Section("Notifications") { ... }
            // Section("Sensitive content") { ... }
        }
        .formStyle(.grouped)
        .frame(width: 380)
        .padding()
    }
}

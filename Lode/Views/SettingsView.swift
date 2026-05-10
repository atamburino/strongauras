import SwiftUI

struct SettingsView: View {
    @AppStorage("historyDepth") private var historyDepth = 50
    @AppStorage("enableRedaction") private var enableRedaction = true
    @AppStorage("launchAtLogin") private var launchAtLogin = false

    private let depthOptions = [10, 50, 100, 200]

    var body: some View {
        Form {
            Section("Clipboard") {
                Picker("History depth", selection: $historyDepth) {
                    ForEach(depthOptions, id: \.self) { n in
                        Text("\(n) entries").tag(n)
                    }
                }

                Toggle("Redact secrets", isOn: $enableRedaction)

                Button("Clear clipboard history", role: .destructive) {
                    DatabaseManager.shared.clearAll()
                }
            }

            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        // TODO: register/deregister SMAppService login item
                    }

                Button("Open data folder") {
                    let url = FileManager.default
                        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                        .appendingPathComponent("Lode")
                    NSWorkspace.shared.open(url)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 360)
        .padding()
    }
}

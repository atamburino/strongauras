import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchPanel: NotchPanel?
    private var clipboardMonitor: ClipboardMonitor?
    private var agentMonitor: AgentMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        AgentMonitor.writeDefaultAgentsFileIfNeeded()

        clipboardMonitor = ClipboardMonitor()
        agentMonitor     = AgentMonitor()

        notchPanel = NotchPanel(agentMonitor: agentMonitor!)
        notchPanel?.show()

        clipboardMonitor?.start()
        agentMonitor?.start()

        setupGlobalShortcut()
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardMonitor?.stop()
        agentMonitor?.stop()
    }

    private func setupGlobalShortcut() {
        // TODO: register global hotkey via Carbon EventHotKey API.
        // Default trigger: Option+Space (user-configurable in Phase 2 settings panel).
        // On trigger: post Notification named "LodeTogglePanel".
    }
}

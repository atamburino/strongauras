import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchPanel: NotchPanel?
    private var clipboardMonitor: ClipboardMonitor?
    private var agentMonitor: AgentMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        clipboardMonitor = ClipboardMonitor()
        agentMonitor = AgentMonitor()

        notchPanel = NotchPanel()
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
        // TODO: register global hotkey (default: Option+Space or configurable)
    }
}

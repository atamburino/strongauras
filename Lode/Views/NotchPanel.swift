import AppKit
import SwiftUI

class NotchPanel: NSPanel {
    private let agentMonitor: AgentMonitor

    init(agentMonitor: AgentMonitor) {
        self.agentMonitor = agentMonitor
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque            = false
        backgroundColor     = .clear
        level               = .statusBar
        collectionBehavior  = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        isMovable           = false
        hasShadow           = false
        isFloatingPanel     = true   // never steal focus from active app

        let content = NotchPanelView(agentMonitor: agentMonitor)
        contentView = NSHostingView(rootView: content)

        positionAtNotch()
    }

    func show() {
        orderFrontRegardless()
    }

    // Position the panel flush against the top edge, centered on the notch.
    // Width matches the safe-zone between camera/sensors; panel expands downward.
    private func positionAtNotch() {
        guard let screen = NSScreen.main else { return }
        // Notch safe zone is approximately 250pt wide on 14"/16" MacBooks
        let pillWidth: CGFloat  = 250
        let pillHeight: CGFloat = 32
        let x = screen.frame.midX - pillWidth / 2
        let y = screen.frame.maxY - pillHeight
        setFrame(NSRect(x: x, y: y, width: pillWidth, height: pillHeight), display: false)
    }
}

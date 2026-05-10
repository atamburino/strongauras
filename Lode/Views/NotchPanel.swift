import AppKit
import SwiftUI

class NotchPanel: NSPanel {
    private var hostingView: NSHostingView<NotchPanelView>?

    convenience init() {
        self.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        isMovable = false
        hasShadow = false

        let content = NotchPanelView()
        let hosting = NSHostingView(rootView: content)
        hosting.layer?.cornerRadius = 12
        hosting.layer?.masksToBounds = true
        contentView = hosting
        self.hostingView = hosting

        positionAtNotch()
    }

    func show() {
        orderFrontRegardless()
    }

    private func positionAtNotch() {
        guard let screen = NSScreen.main else { return }
        let notchWidth: CGFloat = 250
        let notchHeight: CGFloat = 32
        let x = screen.frame.midX - notchWidth / 2
        let y = screen.frame.maxY - notchHeight
        setFrame(NSRect(x: x, y: y, width: notchWidth, height: notchHeight), display: false)
    }
}

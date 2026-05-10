import SwiftUI

struct AgentDotView: View {
    let status: AgentStatus

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .overlay(
                Circle().stroke(color.opacity(0.4), lineWidth: status.state == .running ? 2 : 0)
                    .scaleEffect(1.6)
                    .opacity(status.state == .running ? 0 : 1)
            )
            .help(status.name)
    }

    private var color: Color {
        switch status.state {
        case .running: return .green
        case .waiting: return .orange
        case .stopped: return .gray
        case .errored: return .red
        }
    }
}

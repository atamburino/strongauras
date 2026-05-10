import SwiftUI

// PRD §4.3: 6pt dots on the right edge of the notch, max 4 visible + overflow badge
struct AgentDotsCluster: View {
    let agents: [AgentStatus]

    private let maxVisible = 4

    var body: some View {
        HStack(spacing: 3) {
            // Dots — show running/waiting/errored agents prominently, stopped last
            ForEach(visibleAgents) { agent in
                AgentDot(state: agent.state)
                    .help(label(for: agent))
            }
            if agents.count > maxVisible {
                Text("+\(agents.count - maxVisible)")
                    .font(.system(size: 7, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var visibleAgents: [AgentStatus] {
        // Prioritize non-stopped agents so active ones are always visible
        let sorted = agents.sorted { a, b in priority(a.state) > priority(b.state) }
        return Array(sorted.prefix(maxVisible))
    }

    private func priority(_ state: AgentStatus.State) -> Int {
        switch state {
        case .errored: return 3
        case .running: return 2
        case .waiting: return 1
        case .stopped: return 0
        }
    }

    private func label(for agent: AgentStatus) -> String {
        let stateLabel: String
        switch agent.state {
        case .running: stateLabel = "running"
        case .waiting: stateLabel = "waiting for input"
        case .stopped: stateLabel = "stopped"
        case .errored: stateLabel = "errored"
        }
        return "\(agent.name) — \(stateLabel)"
    }
}

struct AgentDot: View {
    let state: AgentStatus.State

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6) // 6pt per PRD §4.3 UI
    }

    // PRD §4.3 exact hex colors
    private var color: Color {
        switch state {
        case .running: return Color(hex: "#22C55E")
        case .waiting: return Color(hex: "#F97316")
        case .stopped: return Color(hex: "#6B7280")
        case .errored: return Color(hex: "#EF4444")
        }
    }
}

private extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        self.init(
            red:   Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8)  & 0xFF) / 255,
            blue:  Double( rgb        & 0xFF) / 255
        )
    }
}

import SwiftUI

struct NotchPanelView: View {
    @State private var isExpanded = false
    @StateObject private var agentMonitor = AgentMonitor()

    var body: some View {
        VStack(spacing: 0) {
            // Collapsed notch pill — always visible
            NotchPillView(isExpanded: $isExpanded, agents: agentMonitor.statuses)

            if isExpanded {
                NotchDrawerView()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)
    }
}

// The always-visible collapsed state
struct NotchPillView: View {
    @Binding var isExpanded: Bool
    let agents: [AgentStatus]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(agents) { agent in
                AgentDotView(status: agent)
            }
            if agents.isEmpty {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 32)
        .contentShape(Rectangle())
        .onTapGesture { isExpanded.toggle() }
    }
}

// Expanded drawer
struct NotchDrawerView: View {
    var body: some View {
        VStack(spacing: 0) {
            ClipboardListView()
        }
        .frame(width: 320, height: 480)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

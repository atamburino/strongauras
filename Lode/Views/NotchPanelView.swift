import SwiftUI

struct NotchPanelView: View {
    @ObservedObject var agentMonitor: AgentMonitor
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            NotchPillView(isExpanded: $isExpanded, agents: agentMonitor.statuses)

            if isExpanded {
                NotchDrawerView(isExpanded: $isExpanded)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        // ~180ms ease-out per PRD §4.1
        .animation(.easeOut(duration: 0.18), value: isExpanded)
        .onReceive(NotificationCenter.default.publisher(for: .lodeTogglePanel)) { _ in
            isExpanded.toggle()
        }
    }
}

struct NotchPillView: View {
    @Binding var isExpanded: Bool
    let agents: [AgentStatus]

    var body: some View {
        HStack(spacing: 5) {
            Spacer()
            AgentDotsCluster(agents: agents)
        }
        .padding(.trailing, 12)
        .frame(height: 32)
        .contentShape(Rectangle())
        .onTapGesture { isExpanded.toggle() }
    }
}

struct NotchDrawerView: View {
    @Binding var isExpanded: Bool

    var body: some View {
        ClipboardListView(isExpanded: $isExpanded)
            .frame(width: 320, height: 480)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
    }
}

extension Notification.Name {
    static let lodeTogglePanel = Notification.Name("LodeTogglePanel")
}

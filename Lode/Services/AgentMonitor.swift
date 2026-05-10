import Foundation

class AgentMonitor: ObservableObject {
    @Published var statuses: [AgentStatus] = []

    private var timer: Timer?
    private let definitions: [AgentDefinition] = AgentMonitor.loadDefinitions()

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        refresh()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func refresh() {
        var updated: [AgentStatus] = []

        for def in definitions {
            guard let info = findProcess(matching: def) else { continue }
            let state = determineState(pid: info.pid, cpuUsage: info.cpuUsage)
            let existing = statuses.first(where: { $0.pid == info.pid })

            updated.append(AgentStatus(
                id: existing?.id ?? UUID(),
                name: def.name,
                pid: info.pid,
                state: state,
                lastChanged: state != existing?.state ? Date() : (existing?.lastChanged ?? Date()),
                uptimeStart: existing?.uptimeStart ?? Date()
            ))
        }

        DispatchQueue.main.async { self.statuses = updated }
    }

    private func findProcess(matching def: AgentDefinition) -> (pid: pid_t, cpuUsage: Double)? {
        // Query running processes via sysctl / proc_listpids
        // Match by process name, then optionally by path pattern
        // Placeholder — real implementation uses proc_pidinfo or NSRunningApplication
        return nil
    }

    private func determineState(pid: pid_t, cpuUsage: Double) -> AgentStatus.State {
        // CPU idle >10s → .waiting, otherwise .running
        return cpuUsage < 1.0 ? .waiting : .running
    }

    private static func loadDefinitions() -> [AgentDefinition] {
        // Load from bundled agents.json, allow user override
        return [
            AgentDefinition(name: "Claude Code", processName: "claude", pathPattern: nil),
            AgentDefinition(name: "Codex CLI", processName: "codex", pathPattern: nil),
            AgentDefinition(name: "GitHub CLI", processName: "gh", pathPattern: nil),
            AgentDefinition(name: "VS Code Copilot", processName: "node",
                            pathPattern: ".vscode/extensions/github.copilot"),
        ]
    }
}

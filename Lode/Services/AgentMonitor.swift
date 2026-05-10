import Foundation
import AppKit
import os.log

// NOTE: Uses libproc (proc_listallpids, proc_name, proc_pidpath, proc_pidinfo).
// These are available in sandboxed apps without extra entitlements.
// Import is implicit via Darwin on macOS; add `import Darwin` if needed.

private let log = OSLog(subsystem: "com.stone.lode", category: "AgentMonitor")

class AgentMonitor: ObservableObject {
    @Published var statuses: [AgentStatus] = []

    private var timer: Timer?
    private var definitions: [AgentDefinition] = []
    private var agentsFileModDate: Date?

    // Tracks last-seen CPU time per PID to detect idle (PRD §4.3 orange state)
    // "best-effort in v1 — CPU idle >10s = orange" — documented per PRD
    private struct CPURecord {
        var lastCPUNs: UInt64
        var lastActivatedAt: Date
    }
    private var cpuHistory: [pid_t: CPURecord] = [:]

    // PIDs seen in previous cycle — lets us detect clean exits
    private var previousPIDs: Set<pid_t> = []

    func start() {
        reloadDefinitionsIfNeeded()
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.reloadDefinitionsIfNeeded()
            self?.refresh()
        }
        refresh()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - agents.json loading

    private static var userAgentsURL: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Lode/agents.json")
    }

    private func reloadDefinitionsIfNeeded() {
        let url = AgentMonitor.userAgentsURL
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let modDate = attrs?[.modificationDate] as? Date

        guard modDate != agentsFileModDate else { return }
        agentsFileModDate = modDate

        if let data = try? Data(contentsOf: url),
           let file = try? JSONDecoder().decode(AgentsFile.self, from: data) {
            definitions = file.agents
            os_log("Reloaded agents.json (%d agents)", log: log, type: .debug, definitions.count)
        } else if definitions.isEmpty {
            definitions = AgentMonitor.defaultDefinitions
        }
    }

    // Written to disk on first launch by AppDelegate
    static let defaultDefinitions: [AgentDefinition] = {
        let json = """
        {"agents":[
          {"name":"Claude Code","process_name":"claude","match_type":"name"},
          {"name":"Codex CLI","process_name":"codex","match_type":"name"},
          {"name":"GitHub CLI","process_name":"gh","match_type":"name"},
          {"name":"VS Code Copilot","process_name":"node","match_type":"path",
           "path_contains":".vscode/extensions/github.copilot"}
        ]}
        """.data(using: .utf8)!
        return (try? JSONDecoder().decode(AgentsFile.self, from: json))?.agents ?? []
    }()

    static func writeDefaultAgentsFileIfNeeded() {
        let url = userAgentsURL
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        let json = """
        {
          "agents": [
            {"name": "Claude Code",    "process_name": "claude", "match_type": "name"},
            {"name": "Codex CLI",      "process_name": "codex",  "match_type": "name"},
            {"name": "GitHub CLI",     "process_name": "gh",     "match_type": "name"},
            {"name": "VS Code Copilot","process_name": "node",   "match_type": "path",
             "path_contains": ".vscode/extensions/github.copilot"}
          ]
        }
        """
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? json.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - Process polling

    private func refresh() {
        var allPIDs = [pid_t](repeating: 0, count: 4096)
        let count = proc_listallpids(&allPIDs, Int32(allPIDs.count * MemoryLayout<pid_t>.size))
        guard count > 0 else { return }
        let livePIDs = Set(allPIDs.prefix(Int(count)).filter { $0 > 0 })

        var updated: [AgentStatus] = []
        var seenPIDs = Set<pid_t>()

        for def in definitions {
            guard let pid = findPID(for: def, in: livePIDs) else { continue }
            seenPIDs.insert(pid)

            let state = determineState(pid: pid)
            let existing = statuses.first(where: { $0.pid == pid })

            updated.append(AgentStatus(
                id: existing?.id ?? UUID(),
                name: def.name,
                pid: pid,
                state: state,
                lastChanged: state != existing?.state ? Date() : (existing?.lastChanged ?? Date()),
                uptimeStart: existing?.uptimeStart ?? Date()
            ))
        }

        // Prune CPU history for gone PIDs
        for gone in previousPIDs.subtracting(seenPIDs) {
            cpuHistory.removeValue(forKey: gone)
        }
        previousPIDs = seenPIDs

        DispatchQueue.main.async { self.statuses = updated }
    }

    private func findPID(for def: AgentDefinition, in livePIDs: Set<pid_t>) -> pid_t? {
        var nameBuf = [CChar](repeating: 0, count: Int(MAXCOMLEN) + 1)
        var pathBuf = [CChar](repeating: 0, count: Int(MAXPATHLEN))

        for pid in livePIDs {
            proc_name(pid, &nameBuf, UInt32(nameBuf.count))
            let procName = String(cString: nameBuf)
            guard procName == def.processName else { continue }

            switch def.matchType {
            case .name:
                return pid
            case .path:
                guard let pattern = def.pathContains else { return pid }
                proc_pidpath(pid, &pathBuf, UInt32(pathBuf.count))
                let path = String(cString: pathBuf)
                if path.contains(pattern) { return pid }
            }
        }
        return nil
    }

    // CPU idle >10s → .waiting (best-effort; see PRD §4.3 note)
    private func determineState(pid: pid_t) -> AgentStatus.State {
        var info = proc_taskinfo()
        let rc = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, Int32(MemoryLayout<proc_taskinfo>.size))
        guard rc > 0 else { return .running }

        let currentCPUNs = info.pti_total_user + info.pti_total_system
        let now = Date()

        if let record = cpuHistory[pid] {
            if currentCPUNs > record.lastCPUNs {
                cpuHistory[pid] = CPURecord(lastCPUNs: currentCPUNs, lastActivatedAt: now)
                return .running
            } else if now.timeIntervalSince(record.lastActivatedAt) > 10 {
                return .waiting
            } else {
                return .running
            }
        } else {
            cpuHistory[pid] = CPURecord(lastCPUNs: currentCPUNs, lastActivatedAt: now)
            return .running
        }
    }
}

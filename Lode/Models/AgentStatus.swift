import Foundation

struct AgentStatus: Identifiable {
    let id: UUID
    let name: String
    let pid: pid_t
    var state: State
    var lastChanged: Date
    var uptimeStart: Date

    enum State: Equatable {
        case running   // green  #22C55E
        case waiting   // orange #F97316  — CPU idle >10s (best-effort)
        case stopped   // gray   #6B7280
        case errored   // red    #EF4444
    }
}

// Matches agents.json schema from PRD
struct AgentDefinition: Codable {
    let name: String
    let processName: String   // maps from "process_name"
    let matchType: MatchType  // maps from "match_type"
    let pathContains: String? // maps from "path_contains", only used when matchType == .path

    enum MatchType: String, Codable {
        case name
        case path
    }

    enum CodingKeys: String, CodingKey {
        case name
        case processName  = "process_name"
        case matchType    = "match_type"
        case pathContains = "path_contains"
    }
}

// Top-level wrapper matching { "agents": [...] }
struct AgentsFile: Codable {
    let agents: [AgentDefinition]
}

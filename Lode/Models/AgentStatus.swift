import Foundation

struct AgentStatus: Identifiable {
    let id: UUID
    let name: String
    let pid: pid_t
    var state: State
    var lastChanged: Date
    var uptimeStart: Date

    enum State {
        case running    // green
        case waiting    // orange — CPU idle >10s
        case stopped    // gray
        case errored    // red
    }
}

struct AgentDefinition: Codable {
    let name: String
    let processName: String
    let pathPattern: String?  // optional substring match on process path
}

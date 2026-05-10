import Foundation

struct SecretRedactor {
    private let patterns: [NSRegularExpression] = [
        // OpenAI key
        try! NSRegularExpression(pattern: #"sk-[A-Za-z0-9]{32,}"#),
        // GitHub PAT (classic)
        try! NSRegularExpression(pattern: #"ghp_[A-Za-z0-9]{36}"#),
        // GitHub fine-grained PAT
        try! NSRegularExpression(pattern: #"github_pat_[A-Za-z0-9_]{80,}"#),
        // Slack bot token
        try! NSRegularExpression(pattern: #"xoxb-[0-9]+-[A-Za-z0-9-]+"#),
        // AWS access key
        try! NSRegularExpression(pattern: #"AKIA[0-9A-Z]{16}"#),
        // Generic hex secret >40 chars
        try! NSRegularExpression(pattern: #"\b[0-9a-fA-F]{40,}\b"#),
    ]

    // Returns (content, wasRedacted)
    func process(_ text: String) -> (String, Bool) {
        let range = NSRange(text.startIndex..., in: text)
        for pattern in patterns {
            if pattern.firstMatch(in: text, range: range) != nil {
                return (ClipboardEntry.redactedContent, true)
            }
        }
        return (text, false)
    }
}

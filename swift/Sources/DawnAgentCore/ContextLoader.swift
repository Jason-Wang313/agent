import Foundation

/// Assembles the full system prompt from the agent's .md files.
/// Swift equivalent of `build_session_context()` in context_builder.py.
public struct ContextLoader {

    public let agentDirectory: URL
    public let personaURL: URL?
    public let weather: String?
    public let memoryOverride: String?

    public init(
        agentDirectory: URL,
        personaURL: URL? = nil,
        weather: String? = nil,
        memoryOverride: String? = nil
    ) {
        self.agentDirectory = agentDirectory
        self.personaURL = personaURL
        self.weather = weather
        self.memoryOverride = memoryOverride
    }

    // MARK: - Output

    public struct SessionContext {
        /// Full assembled system prompt ready to pass to LanguageModelSession(instructions:)
        public let systemPrompt: String
        /// Rough token estimate (~4 chars per token). Small on-device models target < 3,000.
        public let tokenEstimate: Int
    }

    // MARK: - Build

    public func buildSessionContext() -> SessionContext {
        let now = Date()

        let guardrails = load("guardrails.md")
        let agent      = load("agent.md")
        let persona    = personaURL.map { load(url: $0) } ?? load("persona.md")
        let voice      = load("voice.md")
        let memory     = memoryOverride ?? load("memory.md")
        let topics     = load("topics.md")

        let sessionBlock = """
        # Session Context
        date:         \(formatted(now, "yyyy-MM-dd"))
        day_of_week:  \(formatted(now, "EEEE"))
        time:         \(formatted(now, "HH:mm"))
        time_bracket: \(timeBracket(for: now))
        weather:      \(weather ?? "unavailable")
        """

        let sections: [String] = [
            guardrails,
            agent,
            persona,
            voice,
            sessionBlock,
            "# User Memory\n\(memory)",
            "# Topic Bank (optional reference)\n\(topics)",
        ]

        let systemPrompt  = sections.joined(separator: "\n\n---\n\n")
        let tokenEstimate = systemPrompt.count / 4

        return SessionContext(systemPrompt: systemPrompt, tokenEstimate: tokenEstimate)
    }

    // MARK: - Helpers

    private func load(_ filename: String) -> String {
        load(url: agentDirectory.appendingPathComponent(filename))
    }

    private func load(url: URL) -> String {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            return "<!-- \(url.lastPathComponent) not found — skipping -->"
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func formatted(_ date: Date, _ format: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = format
        return f.string(from: date)
    }

    private func timeBracket(for date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case ..<7:  return "early-morning"
        case ..<10: return "morning"
        default:    return "late-morning"
        }
    }
}

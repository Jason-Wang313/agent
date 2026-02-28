import Foundation

/// Persists memory update blocks to memory.md after each session.
/// Swift equivalent of `write_memory_update()` in context_builder.py.
public struct MemoryWriter {

    public let memoryFileURL: URL

    public init(agentDirectory: URL) {
        self.memoryFileURL = agentDirectory.appendingPathComponent("memory.md")
    }

    public init(memoryFileURL: URL) {
        self.memoryFileURL = memoryFileURL
    }

    // MARK: - Write

    /// Prepend the memory update block under ## SESSION LOG in memory.md.
    /// Returns true on success.
    @discardableResult
    public func writeUpdate(_ updateBlock: String) -> Bool {
        guard var existing = try? String(contentsOf: memoryFileURL, encoding: .utf8) else {
            return false
        }

        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm"
        let timestamp = f.string(from: Date())

        let marker    = "## SESSION LOG"
        let newEntry  = "\(marker)\n\n### [\(timestamp)]\n\(updateBlock)\n"

        if let markerRange = existing.range(of: marker) {
            existing.replaceSubrange(markerRange, with: newEntry)
        } else {
            existing = existing.trimmingCharacters(in: .whitespacesAndNewlines)
                + "\n\n\(newEntry)"
        }

        let final = existing.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
        return (try? final.write(to: memoryFileURL, atomically: true, encoding: .utf8)) != nil
    }

    // MARK: - Budget

    public struct MemoryBudget {
        public let tokenCount: Int
        public let overBudget: Bool
        public let recommendation: String
    }

    /// Check whether memory.md is within the ~600 token target.
    public func checkTokenBudget(warnThreshold: Int = 600) -> MemoryBudget {
        let content    = (try? String(contentsOf: memoryFileURL, encoding: .utf8)) ?? ""
        let tokenCount = content.count / 4
        let over       = tokenCount > warnThreshold

        let recommendation = over
            ? "Memory is ~\(tokenCount) tokens (budget: \(warnThreshold)). Summarise oldest 3 session log entries into one ARCHIVED entry."
            : "Memory is within budget (\(tokenCount) tokens)."

        return MemoryBudget(tokenCount: tokenCount, overBudget: over, recommendation: recommendation)
    }
}

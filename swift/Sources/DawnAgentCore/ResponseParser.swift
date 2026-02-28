import Foundation

/// A single conversation turn from the agent, split into its three uses:
/// TTS rendering, transcript display, and memory persistence.
public struct AgentResponse: Sendable {
    /// Full output with [emotion] tags — feed directly to TTS renderer
    public let emotionTagged: String
    /// Plain text — strip all tags, suitable for transcript display
    public let clean: String
    /// Populated only on session-closing turns; nil otherwise
    public let memoryUpdate: String?
}

/// A single line of agent dialogue broken into its emotion and spoken text.
public struct EmotionLine: Sendable {
    public let tag: String   // e.g. "warm", "curious", "whispering"
    public let text: String  // the spoken content
}

/// Parses raw model output into AgentResponse.
/// Swift equivalent of `parse_response()` in context_builder.py.
public enum ResponseParser {

    // MARK: - Public API

    /// Parse raw model output into a structured AgentResponse.
    public static func parse(_ rawOutput: String) -> AgentResponse {
        let memoryUpdate  = extractMemoryUpdate(from: rawOutput)
        let emotionTagged = stripMemoryBlock(from: rawOutput)
        let clean         = stripEmotionTags(from: emotionTagged)

        return AgentResponse(
            emotionTagged: emotionTagged,
            clean: clean,
            memoryUpdate: memoryUpdate
        )
    }

    /// Break an emotion-tagged response into individual lines for TTS rendering.
    /// Each EmotionLine maps to one TTS utterance with a specific voice affect.
    ///
    /// Example input:  "[warm] Morning...\n[curious] How'd you sleep?"
    /// Example output: [("warm", "Morning..."), ("curious", "How'd you sleep?")]
    public static func parseEmotionLines(from emotionTagged: String) -> [EmotionLine] {
        emotionTagged
            .components(separatedBy: "\n")
            .compactMap { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.hasPrefix("["),
                      let tagEnd = trimmed.firstIndex(of: "]") else { return nil }
                let tag  = String(trimmed[trimmed.index(after: trimmed.startIndex)..<tagEnd])
                let text = trimmed[trimmed.index(after: tagEnd)...]
                    .trimmingCharacters(in: .whitespaces)
                guard !text.isEmpty else { return nil }
                return EmotionLine(tag: tag, text: text)
            }
    }

    // MARK: - Internal helpers

    static func stripEmotionTags(from text: String) -> String {
        // Replace [tag] patterns and collapse extra whitespace
        var result = text
        while let open = result.range(of: "["),
              let close = result.range(of: "]", range: open.upperBound..<result.endIndex) {
            let tagContent = result[open.upperBound..<close.lowerBound]
            // Only strip if it looks like an emotion tag (word chars only)
            if tagContent.allSatisfy({ $0.isLetter || $0 == "_" }) {
                let replacement = result.index(after: close.lowerBound) < result.endIndex
                    && result[result.index(after: close.lowerBound)] == " " ? "" : ""
                result.replaceSubrange(open.lowerBound...close.upperBound, with: replacement)
            } else {
                break // not a tag — stop to avoid infinite loop
            }
        }
        // Clean up leading/trailing whitespace on each line
        return result
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func extractMemoryUpdate(from text: String) -> String? {
        guard let start = text.range(of: "---MEMORY UPDATE---"),
              let end   = text.range(of: "---END UPDATE---",
                                     range: start.upperBound..<text.endIndex) else {
            return nil
        }
        return String(text[start.lowerBound...end.upperBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func stripMemoryBlock(from text: String) -> String {
        guard let start = text.range(of: "---MEMORY UPDATE---"),
              let end   = text.range(of: "---END UPDATE---",
                                     range: start.upperBound..<text.endIndex) else {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        var result = text
        result.removeSubrange(start.lowerBound...end.upperBound)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

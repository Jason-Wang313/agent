import Foundation
import FoundationModels

// MARK: - Errors

public enum DawnAgentError: LocalizedError {
    case modelUnavailable
    case sessionNotStarted

    public var errorDescription: String? {
        switch self {
        case .modelUnavailable:
            return """
            Apple Foundation Model is not available on this device.
            Requires Apple Intelligence: iPhone 15 Pro / iPad with M1+ / Mac with M1+ running macOS 15.1+.
            Ensure Apple Intelligence is enabled in System Settings → Apple Intelligence & Siri.
            """
        case .sessionNotStarted:
            return "Call start() before sending messages."
        }
    }
}

// MARK: - DawnAgentSession

/// Manages a single morning conversation session using Apple's on-device Foundation Model.
///
/// Usage:
///   let session = DawnAgentSession(configuration: .init(agentDirectory: url))
///   try await session.start()
///   let response = try await session.send("Hey")
///   // response.emotionTagged → feed to AVSpeechSynthesizer with emotion-aware SSML
///   // response.clean         → display in transcript view
///   await session.end()
@available(iOS 18.1, macOS 15.1, *)
public final class DawnAgentSession: Sendable {

    // MARK: - Configuration

    public struct Configuration: Sendable {
        /// Directory containing the agent's .md files (agent.md, guardrails.md, memory.md, etc.)
        public let agentDirectory: URL
        /// Override the default persona (agents/default-morning/persona.md) with another file.
        /// Pass a URL from agents/personas/ to swap at session start without editing any file.
        public let personaURL: URL?
        /// Optional weather string injected into session context, e.g. "partly cloudy, 14°C".
        /// Provide via WeatherKit or a weather API before starting the session.
        public let weather: String?

        public init(
            agentDirectory: URL,
            personaURL: URL? = nil,
            weather: String? = nil
        ) {
            self.agentDirectory = agentDirectory
            self.personaURL     = personaURL
            self.weather        = weather
        }
    }

    // MARK: - Properties

    public let configuration: Configuration
    private let memoryWriter: MemoryWriter
    private let _session: OSAllocatedUnfairLock<LanguageModelSession?>
    private let _isActive: OSAllocatedUnfairLock<Bool>

    public var isActive: Bool { _isActive.withLock { $0 } }

    // MARK: - Init

    public init(configuration: Configuration) {
        self.configuration = configuration
        self.memoryWriter  = MemoryWriter(agentDirectory: configuration.agentDirectory)
        self._session      = OSAllocatedUnfairLock(initialState: nil)
        self._isActive     = OSAllocatedUnfairLock(initialState: false)
    }

    // MARK: - Lifecycle

    /// Load .md context files and initialise the on-device Foundation Model session.
    /// Call once before any `send()` or `stream()` calls.
    public func start() async throws {
        // 1. Check Apple Intelligence availability
        guard case .available = SystemLanguageModel.default.availability else {
            throw DawnAgentError.modelUnavailable
        }

        // 2. Assemble system prompt from .md files
        let loader = ContextLoader(
            agentDirectory: configuration.agentDirectory,
            personaURL:     configuration.personaURL,
            weather:        configuration.weather
        )
        let context = loader.buildSessionContext()

        // 3. Warn if context is large — small on-device models prefer < 3,000 tokens
        if context.tokenEstimate > 3_000 {
            print("""
            [DawnAgent] Context is ~\(context.tokenEstimate) tokens — above the 3,000 token \
            target for small on-device models. Consider disabling the Topic Bank section \
            (topics.md) or trimming memory.md.
            """)
        }

        // 4. Create the Foundation Model session
        //    The system prompt (guardrails + agent instructions + persona + voice rules +
        //    session context + memory) is injected as permanent instructions.
        let lmSession = LanguageModelSession(instructions: context.systemPrompt)

        _session.withLock  { $0 = lmSession }
        _isActive.withLock { $0 = true }
    }

    /// End the session and run housekeeping (token budget check).
    public func end() {
        _isActive.withLock { $0 = false }
        _session.withLock  { $0 = nil  }

        let budget = memoryWriter.checkTokenBudget()
        if budget.overBudget {
            print("[DawnAgent] \(budget.recommendation)")
        }
    }

    // MARK: - Conversation

    /// Send a user message and receive a fully parsed AgentResponse.
    /// The session maintains full conversation history internally.
    public func send(_ userMessage: String) async throws -> AgentResponse {
        let lmSession = _session.withLock { $0 }
        guard let lmSession, isActive else { throw DawnAgentError.sessionNotStarted }

        let raw      = try await lmSession.respond(to: userMessage)
        let response = ResponseParser.parse(raw.content)

        persistMemoryUpdate(response.memoryUpdate)
        return response
    }

    /// Stream response tokens as they arrive — ideal for real-time display and TTS.
    /// `onPartial` receives raw text chunks (may include partial emotion tags).
    /// Returns the final parsed AgentResponse when the stream is complete.
    public func stream(
        _ userMessage: String,
        onPartial: @Sendable @escaping (String) -> Void
    ) async throws -> AgentResponse {
        let lmSession = _session.withLock { $0 }
        guard let lmSession, isActive else { throw DawnAgentError.sessionNotStarted }

        var fullText = ""
        for try await partial in lmSession.streamResponse(to: userMessage) {
            onPartial(partial)
            fullText += partial
        }

        let response = ResponseParser.parse(fullText)
        persistMemoryUpdate(response.memoryUpdate)
        return response
    }

    // MARK: - Private

    private func persistMemoryUpdate(_ update: String?) {
        guard let update else { return }
        let success = memoryWriter.writeUpdate(update)
        if !success {
            print("[DawnAgent] Warning: memory update could not be written to disk.")
        }
    }
}

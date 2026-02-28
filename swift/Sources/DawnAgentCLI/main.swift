import Foundation
import DawnAgentCore

// MARK: - Resolve agent directory

// Walk up from the compiled binary to find the repo root's agents/default-morning/
// Swift CLI binary lives at: .build/debug/DawnAgentCLI
// Repo root is three levels up:   ../../..
let binaryURL    = URL(fileURLWithPath: CommandLine.arguments[0]).standardized
let repoRoot     = binaryURL
    .deletingLastPathComponent() // DawnAgentCLI
    .deletingLastPathComponent() // debug
    .deletingLastPathComponent() // .build
    .deletingLastPathComponent() // swift/
let agentDir     = repoRoot.appendingPathComponent("agents/default-morning")

// MARK: - Resolve optional persona (--persona <name>)

var personaURL: URL?
if let idx = CommandLine.arguments.firstIndex(of: "--persona"),
   CommandLine.arguments.count > idx + 1 {
    let name = CommandLine.arguments[idx + 1]
    personaURL = repoRoot.appendingPathComponent("agents/personas/\(name).md")
}

// MARK: - Entry point

Task {
    print("DawnAgent — Apple Foundation Model")
    print("Agent dir: \(agentDir.path)")
    if let p = personaURL { print("Persona:   \(p.lastPathComponent)") }
    print(String(repeating: "-", count: 40))

    if #available(macOS 15.1, *) {
        let config  = DawnAgentSession.Configuration(
            agentDirectory: agentDir,
            personaURL:     personaURL,
            weather:        nil         // TODO: inject via WeatherKit before start()
        )
        let session = DawnAgentSession(configuration: config)

        do {
            try await session.start()
        } catch {
            print("Failed to start session: \(error.localizedDescription)")
            exit(1)
        }

        print("\n[Ready. Type your messages. Enter 'bye' to quit.]\n")

        while true {
            print("You: ", terminator: "")
            guard let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !input.isEmpty else { continue }

            if ["bye", "exit", "quit"].contains(input.lowercased()) {
                print("\n[Session ended]")
                await session.end()
                break
            }

            do {
                // Use streaming so output appears token-by-token in the terminal
                print("\nAgent: ", terminator: "")
                let response = try await session.stream(input) { partial in
                    print(partial, terminator: "")
                    fflush(stdout)
                }
                print("\n")

                // If the response had emotion tags, show the clean version separately
                if response.emotionTagged != response.clean {
                    print("  [clean] \(response.clean)\n")
                }

                // Show which emotions were used (useful for TTS debugging)
                let lines = ResponseParser.parseEmotionLines(from: response.emotionTagged)
                if !lines.isEmpty {
                    let tags = lines.map { "[\($0.tag)]" }.joined(separator: " ")
                    print("  [tags]  \(tags)\n")
                }

            } catch {
                print("\n[Error] \(error.localizedDescription)\n")
            }
        }
    } else {
        print("Error: DawnAgent requires macOS 15.1+ with Apple Intelligence enabled.")
        exit(1)
    }

    exit(0)
}

RunLoop.main.run()

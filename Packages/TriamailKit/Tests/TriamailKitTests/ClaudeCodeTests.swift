import Foundation
import Testing
@testable import TriamailKit

@Suite struct ClaudeCodeTests {
    @Test func explicitMappingWinsThenCodeFolder() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("triamail-code-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root.appendingPathComponent("projet"), withIntermediateDirectories: true)

        let mapped = ClaudeCodeLaunch.folder(for: "exemple/projet", mapping: ["exemple/projet": "/tmp/ailleurs"], codeRoot: root.path)
        #expect(mapped?.path == "/tmp/ailleurs")
        let found = ClaudeCodeLaunch.folder(for: "exemple/projet", mapping: [:], codeRoot: root.path)
        #expect(found?.lastPathComponent == "projet")
        #expect(ClaudeCodeLaunch.folder(for: "exemple/absent", mapping: [:], codeRoot: root.path) == nil)
        #expect(ClaudeCodeLaunch.folder(for: "exemple/projet", mapping: [:], codeRoot: nil) == nil)
    }

    @Test func scriptQuotesEverythingForTheShell() {
        let launch = ClaudeCodeLaunch(folder: URL(fileURLWithPath: "/Users/exemple/code/l'projet"), prompt: "C'est « urgent » ; rm -rf $HOME `x`")
        #expect(launch.script.contains("cd '/Users/exemple/code/l'\\''projet' || exit 1"))
        #expect(launch.script.contains("exec claude 'C'\\''est « urgent » ; rm -rf $HOME `x`'"))
    }

    @Test func promptCarriesTheNotificationAndItsLink() {
        let message = MailMessage(id: "m", threadID: "t", account: "jeanne@exemple.com", from: "GitHub <notifications@github.com>",
                                  to: "", cc: "", subject: "[exemple/projet] CI échouée", date: .now, snippet: "", listID: nil,
                                  labelIDs: [], plainText: "Voir https://github.com/exemple/projet/actions/runs/42", html: nil, attachments: [])
        let prompt = ClaudeCodeLaunch.prompt(for: message)
        #expect(prompt.contains("« [exemple/projet] CI échouée »"))
        #expect(prompt.contains("Lien : https://github.com/exemple/projet/actions/runs/42"))
        #expect(prompt.contains("avant d'agir"))
    }
}

import AppKit
import TriamailKit

/// Writes the launch script and opens it with the chosen terminal.
enum ClaudeCodeLauncher {
    static let terminals: [(name: String, bundleID: String)] = [
        ("Terminal", "com.apple.Terminal"),
        ("iTerm2", "com.googlecode.iterm2"),
    ]

    static func launch(_ message: MailMessage, settings: SharedSettings) async throws {
        guard let repository = message.gitHubRepository else { throw LaunchError.notGitHub }
        guard let folder = ClaudeCodeLaunch.folder(for: repository, mapping: settings.repositoryFolders, codeRoot: settings.codeRoot) else {
            throw LaunchError.noFolder(repository)
        }
        let launch = ClaudeCodeLaunch(folder: folder, prompt: ClaudeCodeLaunch.prompt(for: message))
        let script = FileManager.default.temporaryDirectory.appendingPathComponent("triamail-claude-\(UUID().uuidString).command")
        try launch.script.write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: script.path)
        guard let terminal = NSWorkspace.shared.urlForApplication(withBundleIdentifier: settings.terminalBundleID)
            ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: SharedSettings.defaultTerminal) else {
            throw LaunchError.noTerminal
        }
        _ = try await NSWorkspace.shared.open([script], withApplicationAt: terminal, configuration: NSWorkspace.OpenConfiguration())
    }

    enum LaunchError: LocalizedError {
        case notGitHub, noTerminal
        case noFolder(String)

        var errorDescription: String? {
            switch self {
            case .notGitHub: "Ce mail n'est pas une notification GitHub."
            case .noTerminal: "Terminal introuvable."
            case let .noFolder(repository): "Pas de dossier local pour \(repository) : règle le dossier des dépôts dans Réglages > Général."
            }
        }
    }
}

import Foundation

/// C2: open Claude Code, locally, in the repository a GitHub notification is about.
public struct ClaudeCodeLaunch: Equatable, Sendable {
    public var folder: URL
    public var prompt: String

    public init(folder: URL, prompt: String) {
        self.folder = folder
        self.prompt = prompt
    }

    /// The repository's folder: an explicit mapping first, else "<code folder>/<repo name>" if it exists.
    public static func folder(for repository: String, mapping: [String: String], codeRoot: String?, fileManager: FileManager = .default) -> URL? {
        if let path = mapping[repository] ?? mapping[repository.lowercased()] {
            return path.expandingTildeURL
        }
        guard let codeRoot, let name = repository.split(separator: "/").last else { return nil }
        let candidate = codeRoot.expandingTildeURL.appendingPathComponent(String(name), isDirectory: true)
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: candidate.path, isDirectory: &isDirectory) && isDirectory.boolValue ? candidate : nil
    }

    public static func prompt(for message: MailMessage) -> String {
        let link = message.primaryLink.map { "\nLien : \($0.absoluteString)" } ?? ""
        return """
        Notification GitHub reçue par mail : « \(message.subject) »\(link)

        \(String(message.plainText.prefix(4_000)))

        Regarde ce que cette notification demande (tu peux utiliser `gh`), puis propose-moi quoi faire avant d'agir.
        """
    }

    /// A `.command` script the terminal runs: go to the folder, start Claude Code with the notification.
    public var script: String {
        """
        #!/bin/zsh -l
        cd \(Self.shellQuoted(folder.path)) || exit 1
        exec claude \(Self.shellQuoted(prompt))

        """
    }

    /// 'single quotes', with any ' inside closed, escaped and reopened.
    static func shellQuoted(_ text: String) -> String {
        "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

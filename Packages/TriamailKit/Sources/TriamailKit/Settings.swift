import Foundation

/// Settings shared between Macs, stored as readable JSON in the settings folder (iCloud Drive by default).
/// Secrets never go here: they live in the keychain.
public struct SharedSettings: Codable, Equatable, Sendable {
    public static let currentVersion = 1
    public static let defaultTerminal = "com.apple.Terminal"

    public var version = SharedSettings.currentVersion
    public var archiveFolders: [ArchiveFolder] = []
    public var archiveRules: [ArchiveRule] = []
    /// The Reminders list for C4; nil means the default list.
    public var remindersListName: String?
    public var profile = Profile()
    public var aiProvider = AIProvider.appleLocal
    /// Where the repositories are cloned ("~/code"): "owner/repo" is looked for there by name.
    public var codeRoot: String?
    /// Exceptions: "owner/repo" → "~/somewhere/else".
    public var repositoryFolders: [String: String] = [:]
    /// The terminal app that runs Claude Code.
    public var terminalBundleID = SharedSettings.defaultTerminal
    public var mistralModel = MistralClient.defaultModel
    /// Folders the "Tidy" button goes through (Downloads, Desktop, scans…), as "~/…" paths.
    public var tidySourcePaths: [String] = []

    public init(archiveFolders: [ArchiveFolder] = [], archiveRules: [ArchiveRule] = [], remindersListName: String? = nil) {
        self.archiveFolders = archiveFolders
        self.archiveRules = archiveRules
        self.remindersListName = remindersListName
    }

    // Missing keys keep their default, so older files keep loading as settings grow.
    public init(from decoder: Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) throws -> T {
            try container.decodeIfPresent(T.self, forKey: key) ?? fallback
        }
        version = try value(.version, version)
        archiveFolders = try value(.archiveFolders, archiveFolders)
        archiveRules = try value(.archiveRules, archiveRules)
        remindersListName = try container.decodeIfPresent(String.self, forKey: .remindersListName)
        profile = try value(.profile, profile)
        aiProvider = try value(.aiProvider, aiProvider)
        codeRoot = try container.decodeIfPresent(String.self, forKey: .codeRoot)
        repositoryFolders = try value(.repositoryFolders, repositoryFolders)
        terminalBundleID = try value(.terminalBundleID, terminalBundleID)
        mistralModel = try value(.mistralModel, mistralModel)
        tidySourcePaths = try value(.tidySourcePaths, tidySourcePaths)
    }
}

/// Reads and writes the settings folder:
///
///     Triamail/
///       reglages.json
///       modeles/
///         repondre.md
///         …
public struct SettingsStore: Sendable {
    public static let settingsFileName = "reglages.json"
    public static let templatesFolderName = "modeles"

    /// iCloud Drive's "Triamail" folder: synced between Macs with no developer account needed.
    public static var defaultFolder: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs/Triamail", isDirectory: true)
    }

    public let folder: URL

    public init(folder: URL) {
        self.folder = folder
    }

    public var settingsFile: URL { folder.appendingPathComponent(Self.settingsFileName) }
    public var templatesFolder: URL { folder.appendingPathComponent(Self.templatesFolderName, isDirectory: true) }

    /// Empty settings when the file does not exist yet.
    public func load() throws -> SharedSettings {
        guard FileManager.default.fileExists(atPath: settingsFile.path) else { return SharedSettings() }
        return try JSONDecoder().decode(SharedSettings.self, from: Data(contentsOf: settingsFile))
    }

    public func save(_ settings: SharedSettings) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(settings).write(to: settingsFile, options: .atomic)
    }

    /// Reply templates: one text file per template, named after the file.
    public func templates() throws -> [ReplyTemplate] {
        guard FileManager.default.fileExists(atPath: templatesFolder.path) else { return [] }
        return try FileManager.default
            .contentsOfDirectory(at: templatesFolder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            .filter { ["md", "txt"].contains($0.pathExtension.lowercased()) && $0.lastPathComponent.lowercased() != "readme.md" }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .map { ReplyTemplate(id: $0.deletingPathExtension().lastPathComponent, contents: try String(contentsOf: $0, encoding: .utf8)) }
    }

    /// Writes the template to its file. A new template, or one whose title changed, gets its file name
    /// from the title (`<slug>.md`, the old file goes away). Returns the template as read back from disk.
    @discardableResult
    public func save(_ template: ReplyTemplate) throws -> ReplyTemplate {
        try FileManager.default.createDirectory(at: templatesFolder, withIntermediateDirectories: true)
        let existing = try templates()
        var id = template.id
        if id.isEmpty || existing.first(where: { $0.id == template.id })?.title != template.title {
            // Compared without case: the Mac's disk does not tell "Relance.md" from "relance.md".
            let taken = Set(existing.map { $0.id.lowercased() }).subtracting([template.id.lowercased()])
            let base = template.title.fileNameSlug.isEmpty ? "modele" : template.title.fileNameSlug
            id = base
            var counter = 2
            while taken.contains(id) {
                id = "\(base)-\(counter)"
                counter += 1
            }
            if id == template.id.lowercased() { id = template.id }
        }
        var saved = template
        saved.id = id
        try saved.fileContents.write(to: file(for: id), atomically: true, encoding: .utf8)
        if id != template.id, !template.id.isEmpty {
            try? FileManager.default.removeItem(at: file(for: template.id))
        }
        return ReplyTemplate(id: id, contents: saved.fileContents)
    }

    public func deleteTemplate(id: ReplyTemplate.ID) throws {
        try FileManager.default.removeItem(at: file(for: id))
    }

    /// `.md`, or the `.txt` an older template may still use.
    private func file(for id: ReplyTemplate.ID) -> URL {
        let text = templatesFolder.appendingPathComponent("\(id).txt")
        return FileManager.default.fileExists(atPath: text.path) ? text : templatesFolder.appendingPathComponent("\(id).md")
    }

    /// The bundled templates already copied once (a hidden file in `modeles/`): one the user deleted
    /// or renamed is not copied again.
    var installedTemplatesRecord: URL { templatesFolder.appendingPathComponent(".installes") }

    /// Copies the bundled templates into the settings folder once each, never overwriting the user's prompts.
    /// A copy from before front matter existed gets the bundled title, shortcut and icon on top of its own
    /// prompt, so it does not lose its button's shortcut. A file that already has front matter is left alone.
    public func installTemplates(from bundled: URL) throws {
        try FileManager.default.createDirectory(at: templatesFolder, withIntermediateDirectories: true)
        let record = (try? String(contentsOf: installedTemplatesRecord, encoding: .utf8)) ?? ""
        var installed = Set(record.split(separator: "\n").map(String.init))
        let files = try FileManager.default.contentsOfDirectory(at: bundled, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        for file in files where file.pathExtension.lowercased() == "md" && file.lastPathComponent.lowercased() != "readme.md" {
            let destination = templatesFolder.appendingPathComponent(file.lastPathComponent)
            if FileManager.default.fileExists(atPath: destination.path) {
                // Best effort: an unreadable file (being synced, another encoding) stays as it is.
                try? addFrontMatter(from: file, to: destination)
            } else if !installed.contains(file.lastPathComponent) {
                try FileManager.default.copyItem(at: file, to: destination)
            }
            installed.insert(file.lastPathComponent)
        }
        try installed.sorted().joined(separator: "\n").write(to: installedTemplatesRecord, atomically: true, encoding: .utf8)
    }

    private func addFrontMatter(from bundled: URL, to destination: URL) throws {
        let mine = try String(contentsOf: destination, encoding: .utf8)
        let theirs = try String(contentsOf: bundled, encoding: .utf8)
        guard ReplyTemplate.frontMatter(in: mine) == nil, ReplyTemplate.frontMatter(in: theirs) != nil else { return }
        var upgraded = ReplyTemplate(id: destination.deletingPathExtension().lastPathComponent, contents: theirs)
        upgraded.prompt = mine
        try upgraded.fileContents.write(to: destination, atomically: true, encoding: .utf8)
    }
}


extension String {
    /// "~/Downloads" → the folder's URL on this Mac.
    public var expandingTildeURL: URL {
        URL(fileURLWithPath: (self as NSString).expandingTildeInPath, isDirectory: true)
    }

    /// "/Users/jeanne/Documents" → "~/Documents", so paths stay valid on another Mac with the same layout.
    public var abbreviatingHomeDirectory: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        guard hasPrefix(home + "/") || self == home else { return self }
        return "~" + dropFirst(home.count)
    }
}

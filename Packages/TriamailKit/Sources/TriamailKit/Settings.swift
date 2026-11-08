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
            .map { ReplyTemplate(id: $0.deletingPathExtension().lastPathComponent, prompt: try String(contentsOf: $0, encoding: .utf8)) }
    }

    /// Copies the bundled templates into the settings folder, never overwriting the user's own.
    public func installTemplates(from bundled: URL) throws {
        try FileManager.default.createDirectory(at: templatesFolder, withIntermediateDirectories: true)
        let files = try FileManager.default.contentsOfDirectory(at: bundled, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        for file in files where file.pathExtension.lowercased() == "md" && file.lastPathComponent.lowercased() != "readme.md" {
            let destination = templatesFolder.appendingPathComponent(file.lastPathComponent)
            if !FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.copyItem(at: file, to: destination)
            }
        }
    }
}

public struct ReplyTemplate: Identifiable, Equatable, Sendable {
    public var id: String
    public var prompt: String

    public init(id: String, prompt: String) {
        self.id = id
        self.prompt = prompt
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

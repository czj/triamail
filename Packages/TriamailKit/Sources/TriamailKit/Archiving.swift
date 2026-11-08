import Foundation

/// A local folder where documents are archived. Syncing (Google Drive, iCloud Drive…) is left to the system.
public struct ArchiveFolder: Codable, Hashable, Identifiable, Sendable {
    public enum Subfolder: String, Codable, Sendable {
        case none
        case year
        case yearMonth
    }

    public var id: UUID
    public var name: String
    public var path: String
    /// Prefix file names with "yyyy-MM-dd - ".
    public var datePrefix: Bool
    public var subfolder: Subfolder
    /// Where invoices archived here are sent for accounting (an import address), if any.
    public var accountingEmail: String?

    public init(id: UUID = UUID(), name: String, path: String, datePrefix: Bool = true, subfolder: Subfolder = .none, accountingEmail: String? = nil) {
        self.id = id
        self.name = name
        self.path = path
        self.datePrefix = datePrefix
        self.subfolder = subfolder
        self.accountingEmail = accountingEmail
    }

    public var url: URL { URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true) }
}

/// "If the sender, the file name or the PDF text matches, then this folder, this name, accounting or not."
public struct ArchiveRule: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    /// Matches when the sender address contains this text (case-insensitive), e.g. "@exemple.com".
    public var senderContains: String?
    /// Regular expression matched against the original file name.
    public var fileNamePattern: String?
    /// Every one of these strings must appear in the document text (case-insensitive).
    public var textContainsAll: [String]
    public var folderID: ArchiveFolder.ID
    /// New base name without date nor extension, e.g. "Facture Exemple". Nil keeps the original name.
    public var renameTo: String?
    public var sendToAccounting: Bool

    public init(
        id: UUID = UUID(),
        senderContains: String? = nil,
        fileNamePattern: String? = nil,
        textContainsAll: [String] = [],
        folderID: ArchiveFolder.ID,
        renameTo: String? = nil,
        sendToAccounting: Bool = false
    ) {
        self.id = id
        self.senderContains = senderContains
        self.fileNamePattern = fileNamePattern
        self.textContainsAll = textContainsAll
        self.folderID = folderID
        self.renameTo = renameTo
        self.sendToAccounting = sendToAccounting
    }

    /// A rule with no condition at all never matches.
    var hasCondition: Bool {
        senderContains?.isEmpty == false || fileNamePattern?.isEmpty == false || !textContainsAll.isEmpty
    }

    public func matches(_ document: Document) -> Bool {
        guard hasCondition else { return false }
        if let sender = senderContains, !sender.isEmpty {
            guard let from = document.sender, from.localizedCaseInsensitiveContains(sender) else { return false }
        }
        if let pattern = fileNamePattern, !pattern.isEmpty {
            guard let regex = try? Regex(pattern), document.fileName.contains(regex) else { return false }
        }
        if !textContainsAll.isEmpty {
            guard let text = document.text() else { return false }
            guard textContainsAll.allSatisfy({ text.localizedCaseInsensitiveContains($0) }) else { return false }
        }
        return true
    }
}

/// A file to archive: a mail attachment or a file in a watched folder.
public struct Document: Sendable {
    public var fileName: String
    public var sender: String?
    /// The date used in the archived name: the mail's date, or the file's for a local file.
    public var date: Date
    /// Extracted text, computed only when a rule needs it.
    public var text: @Sendable () -> String?

    public init(fileName: String, sender: String? = nil, date: Date, text: @escaping @Sendable () -> String? = { nil }) {
        self.fileName = fileName.precomposedStringWithCanonicalMapping
        self.sender = sender
        self.date = date
        self.text = text
    }
}

/// Where a document will go, shown to the user before anything moves.
public struct ArchivePlan: Equatable, Sendable {
    public var rule: ArchiveRule
    public var folder: ArchiveFolder
    public var directory: URL
    public var fileName: String

    public var destination: URL { directory.appendingPathComponent(fileName) }
}

public struct ArchivePlanner: Sendable {
    public var folders: [ArchiveFolder]
    public var rules: [ArchiveRule]
    public var calendar: Calendar

    public init(folders: [ArchiveFolder], rules: [ArchiveRule], calendar: Calendar = .current) {
        self.folders = folders
        self.rules = rules
        self.calendar = calendar
    }

    /// The first matching rule wins, as in the original script.
    public func plan(for document: Document) -> ArchivePlan? {
        for rule in rules where rule.matches(document) {
            guard let folder = folders.first(where: { $0.id == rule.folderID }) else { continue }
            return ArchivePlan(
                rule: rule,
                folder: folder,
                directory: directory(in: folder, for: document.date),
                fileName: fileName(for: document, rule: rule, folder: folder)
            )
        }
        return nil
    }

    func fileName(for document: Document, rule: ArchiveRule, folder: ArchiveFolder) -> String {
        let original = document.fileName as NSString
        let ext = original.pathExtension.lowercased()
        let base = rule.renameTo ?? original.deletingPathExtension
        let alreadyDated = base.wholeMatch(of: /\d{4}-\d{2}-\d{2} - .*/) != nil
        let dated = (folder.datePrefix || rule.renameTo != nil) && !alreadyDated
            ? "\(dayString(document.date)) - \(base)"
            : base
        return ext.isEmpty ? dated : "\(dated).\(ext)"
    }

    func directory(in folder: ArchiveFolder, for date: Date) -> URL {
        let parts = calendar.dateComponents([.year, .month], from: date)
        let year = String(format: "%04d", parts.year ?? 0)
        let month = String(format: "%02d", parts.month ?? 0)
        switch folder.subfolder {
        case .none: return folder.url
        case .year: return folder.url.appendingPathComponent(year, isDirectory: true)
        case .yearMonth: return folder.url.appendingPathComponent("\(year)-\(month)", isDirectory: true)
        }
    }

    func dayString(_ date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

extension URL {
    /// "name.pdf" if free, else "name - 1.pdf", "name - 2.pdf"…
    public func uniqued(fileManager: FileManager = .default) -> URL {
        guard fileManager.fileExists(atPath: path) else { return self }
        let directory = deletingLastPathComponent()
        let ext = pathExtension
        let base = deletingPathExtension().lastPathComponent
        var index = 1
        while true {
            let name = ext.isEmpty ? "\(base) - \(index)" : "\(base) - \(index).\(ext)"
            let candidate = directory.appendingPathComponent(name)
            if !fileManager.fileExists(atPath: candidate.path) { return candidate }
            index += 1
        }
    }
}

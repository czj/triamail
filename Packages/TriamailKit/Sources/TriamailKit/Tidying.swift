import Foundation

/// One file to move, shown to the user before anything moves.
public struct TidyMove: Identifiable, Equatable, Sendable {
    public var id: URL { source }
    public var source: URL
    public var plan: ArchivePlan
}

/// The "Tidy" button: the archive rules applied to local folders (Downloads, Desktop, scans…),
/// then the archive folders' own dating for files dropped there by hand. Replaces the old script.
public struct FolderTidier: Sendable {
    public var planner: ArchivePlanner
    public var sourceFolders: [URL]

    public init(planner: ArchivePlanner, sourceFolders: [URL]) {
        self.planner = planner
        self.sourceFolders = sourceFolders
    }

    public func plan(fileManager: FileManager = .default) -> [TidyMove] {
        var moves: [TidyMove] = []
        for folder in sourceFolders {
            for file in Self.files(in: folder, fileManager: fileManager) {
                if let plan = planner.plan(for: Self.document(for: file, fileManager: fileManager)) {
                    moves.append(TidyMove(source: file, plan: plan))
                }
            }
        }
        moves += datingMoves(fileManager: fileManager)
        return moves.filter { $0.source.standardizedFileURL != $0.plan.destination.standardizedFileURL }
    }

    /// Files lying at the root of an archive folder that dates its files: prefix and subfolder them.
    func datingMoves(fileManager: FileManager) -> [TidyMove] {
        planner.folders.filter { $0.datePrefix || $0.subfolder != .none }.flatMap { folder in
            Self.files(in: folder.url, fileManager: fileManager).map { file in
                let document = Self.document(for: file, fileManager: fileManager)
                let rule = ArchiveRule(fileNamePattern: ".", folderID: folder.id)
                return TidyMove(source: file, plan: ArchivePlan(
                    rule: rule,
                    folder: folder,
                    directory: planner.directory(in: folder, for: document.date),
                    fileName: planner.fileName(for: document, rule: rule, folder: folder)
                ))
            }
        }
    }

    /// Moves the files, never overwriting. Returns where each one went.
    @discardableResult
    public static func apply(_ moves: [TidyMove], fileManager: FileManager = .default) throws -> [URL] {
        try moves.map { move in
            try fileManager.createDirectory(at: move.plan.directory, withIntermediateDirectories: true)
            let destination = move.plan.destination.uniqued(fileManager: fileManager)
            try fileManager.moveItem(at: move.source, to: destination)
            return destination
        }
    }

    static func files(in folder: URL, fileManager: FileManager) -> [URL] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .creationDateKey]
        let contents = (try? fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])) ?? []
        return contents
            .filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// The file's creation date stands for the mail's date; its text is read only if a rule asks.
    static func document(for file: URL, fileManager: FileManager) -> Document {
        let date = (try? file.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .now
        let isPDF = file.pathExtension.lowercased() == "pdf"
        return Document(fileName: file.lastPathComponent, date: date) {
            isPDF ? (try? Data(contentsOf: file)).flatMap(PDFText.extract) : nil
        }
    }
}

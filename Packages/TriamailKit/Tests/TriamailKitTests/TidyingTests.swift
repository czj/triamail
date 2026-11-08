import Foundation
import Testing
@testable import TriamailKit

@Suite struct TidyingTests {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("triamail-tidy-\(UUID().uuidString)", isDirectory: true)

    func make(_ path: String, contents: String = "x") throws -> URL {
        let url = root.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(contents.utf8).write(to: url)
        return url
    }

    @Test func movesMatchingDownloadsAndDatesFilesDroppedInArchiveFolders() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let downloads = root.appendingPathComponent("Téléchargements", isDirectory: true)
        let purchases = ArchiveFolder(name: "Achats", path: root.appendingPathComponent("Achats").path, datePrefix: true, subfolder: .year)
        let rule = ArchiveRule(fileNamePattern: "^INV-", folderID: purchases.id, renameTo: "Facture Exemple")
        _ = try make("Téléchargements/INV-001.pdf")
        _ = try make("Téléchargements/photo.jpg")
        _ = try make("Téléchargements/.cache")
        _ = try make("Achats/devis.pdf")
        _ = try make("Achats/2026/2026-01-02 - Facture.pdf")

        let tidier = FolderTidier(planner: ArchivePlanner(folders: [purchases], rules: [rule]), sourceFolders: [downloads])
        let moves = tidier.plan()
        let year = String(Calendar.current.component(.year, from: .now))
        let day = ArchivePlanner(folders: [], rules: []).dayString(.now)
        #expect(moves.map(\.source.lastPathComponent).sorted() == ["INV-001.pdf", "devis.pdf"])
        #expect(moves.map(\.plan.fileName).sorted() == ["\(day) - Facture Exemple.pdf", "\(day) - devis.pdf"])

        let destinations = try FolderTidier.apply(moves)
        #expect(destinations.allSatisfy { $0.deletingLastPathComponent().lastPathComponent == year })
        #expect(FileManager.default.fileExists(atPath: downloads.appendingPathComponent("photo.jpg").path))
        #expect(!FileManager.default.fileExists(atPath: downloads.appendingPathComponent("INV-001.pdf").path))
        #expect(FolderTidier(planner: tidier.planner, sourceFolders: [downloads]).plan().isEmpty)
    }

    @Test func oldSettingsHaveNoTidyFolders() throws {
        let settings = try JSONDecoder().decode(SharedSettings.self, from: Data(#"{"version":1}"#.utf8))
        #expect(settings.tidySourcePaths.isEmpty)
    }
}

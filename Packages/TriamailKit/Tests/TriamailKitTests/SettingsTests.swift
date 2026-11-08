import Foundation
import Testing
@testable import TriamailKit

@Suite struct SettingsTests {
    func temporaryFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("triamail-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    @Test func missingFileGivesEmptySettings() throws {
        let store = SettingsStore(folder: try temporaryFolder().appendingPathComponent("absent"))
        #expect(try store.load() == SharedSettings())
    }

    @Test func saveThenLoadRoundTrips() throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = SettingsStore(folder: folder.appendingPathComponent("Triamail"))
        let purchases = ArchiveFolder(name: "Achats Exemple", path: "~/Documents/Achats", subfolder: .year)
        let rule = ArchiveRule(senderContains: "@exemple.com", folderID: purchases.id, renameTo: "Facture Exemple", sendToAccounting: true)
        let settings = SharedSettings(archiveFolders: [purchases], archiveRules: [rule])

        try store.save(settings)
        #expect(try store.load() == settings)
        let json = try String(contentsOf: store.settingsFile, encoding: .utf8)
        #expect(json.contains("\"renameTo\" : \"Facture Exemple\""))
    }

    @Test func olderFileWithMissingKeysStillLoads() throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        try Data(#"{ "version": 1 }"#.utf8).write(to: folder.appendingPathComponent(SettingsStore.settingsFileName))
        let settings = try SettingsStore(folder: folder).load()
        #expect(settings.archiveFolders.isEmpty)
        #expect(settings.archiveRules.isEmpty)
    }

    @Test func installTemplatesNeverOverwritesUserFiles() throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let bundled = folder.appendingPathComponent("bundled", isDirectory: true)
        try FileManager.default.createDirectory(at: bundled, withIntermediateDirectories: true)
        try "Livré".write(to: bundled.appendingPathComponent("repondre.md"), atomically: true, encoding: .utf8)
        try "Livré".write(to: bundled.appendingPathComponent("loufoque.md"), atomically: true, encoding: .utf8)
        try "Doc".write(to: bundled.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)

        let store = SettingsStore(folder: folder.appendingPathComponent("Triamail"))
        try FileManager.default.createDirectory(at: store.templatesFolder, withIntermediateDirectories: true)
        try "Le mien".write(to: store.templatesFolder.appendingPathComponent("repondre.md"), atomically: true, encoding: .utf8)

        try store.installTemplates(from: bundled)
        let templates = try store.templates()
        #expect(templates.map(\.id) == ["loufoque", "repondre"])
        #expect(templates.first { $0.id == "repondre" }?.prompt == "Le mien")
    }

    @Test func homeDirectoryIsAbbreviated() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        #expect("\(home)/Documents/Achats".abbreviatingHomeDirectory == "~/Documents/Achats")
        #expect("/Volumes/Disque/Achats".abbreviatingHomeDirectory == "/Volumes/Disque/Achats")
        let folder = ArchiveFolder(name: "x", path: "~/Documents")
        #expect(folder.url.path == "\(home)/Documents")
    }
}

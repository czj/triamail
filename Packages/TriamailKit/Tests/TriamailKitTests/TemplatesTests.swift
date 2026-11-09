import Foundation
import Testing
@testable import TriamailKit

@Suite struct TemplatesTests {
    var profile: Profile {
        var profile = Profile()
        profile.firstName = "Jeanne"
        profile.fullName = "Jeanne Exemple"
        profile.company = "Exemple SAS"
        profile.supportURL = "https://exemple.com/contact"
        return profile
    }

    @Test func listsArgumentsOnceInOrder() {
        let template = ReplyTemplate(id: "repondre", prompt: #"A {argument name="Intention et ton"} B {argument name="Guidance" default="x"} C {argument name="Intention et ton"}"#)
        #expect(template.arguments == ["Intention et ton", "Guidance"])
    }

    @Test func rendersProfileSelectionAndArguments() {
        let template = ReplyTemplate(id: "repondre", prompt: """
        Tu écris pour {profil.nom_complet} ({profil.entreprise}). Signe « {profil.prenom} ».
        Fil : {selection}
        Intention : {argument name="Intention et ton"}
        Support : {profil.url_support} {profil.inconnu}
        """)
        let text = template.render(profile: profile, selection: "Bonjour !", arguments: ["Intention et ton": "poli mais non"])
        #expect(text == """
        Tu écris pour Jeanne Exemple (Exemple SAS). Signe « Jeanne ».
        Fil : Bonjour !
        Intention : poli mais non
        Support : https://exemple.com/contact 
        """)
    }

    @Test func bundledTemplatesUseOnlyKnownVariables() throws {
        let folder = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("modeles")
        let templates = try SettingsStore(folder: folder.deletingLastPathComponent()).templates()
        #expect(templates.count >= 5)
        let known = Set(Profile().variables.keys)
        for template in templates {
            for match in template.prompt.matches(of: /\{profil\.([a-z_]+)\}/) {
                #expect(known.contains(String(match.1)), "\(template.id) : {profil.\(match.1)} inconnu")
            }
            #expect(!template.render(profile: profile, selection: "x").contains("{profil."))
        }
    }

    @Test func readsFrontMatter() {
        let template = ReplyTemplate(id: "repondre", contents: """
        ---
        titre: Répondre poliment
        bouton: Répondre
        raccourci: cmd+shift+1
        icone: arrowshape.turn.up.left
        ---
        Fil : {selection}
        """)
        #expect(template.title == "Répondre poliment")
        #expect(template.label == "Répondre")
        #expect(template.shortcut == TemplateShortcut(modifiers: [.cmd, .shift], key: "1"))
        #expect(template.icon == "arrowshape.turn.up.left")
        #expect(template.prompt == "Fil : {selection}")
    }

    @Test func withoutFrontMatterTheFileNameIsTheTitle() {
        let text = "Bonjour\n-----------------------------\n{selection}"
        let template = ReplyTemplate(id: "dites-m-en-plus", contents: text)
        #expect(template.title == "Dites m en plus")
        #expect(template.label == "Dites m en plus")
        #expect(template.shortcut == nil)
        #expect(template.prompt == text)
    }

    @Test func fileContentsReadBack() {
        let template = ReplyTemplate(id: "x", title: "Oubliez-moi", buttonLabel: "", shortcut: TemplateShortcut("ctrl+option+o"), icon: "hand.raised", prompt: "Texte\n\nsur plusieurs lignes")
        #expect(ReplyTemplate(id: "x", contents: template.fileContents) == template)
        #expect(template.shortcut?.rawValue == "option+control+o")
        #expect(template.shortcut?.symbols == "⌃⌥O")
    }

    @Test func parsesShortcuts() {
        #expect(TemplateShortcut("Command+Shift+R") == TemplateShortcut(modifiers: [.cmd, .shift], key: "r"))
        #expect(TemplateShortcut("cmd+shift+1")?.symbols == "⇧⌘1")
        #expect(TemplateShortcut("cmd+shift+1")?.rawValue == "cmd+shift+1")
        #expect(TemplateShortcut("cmd+") == nil)
        #expect(TemplateShortcut("hyper+a") == nil)
        #expect(TemplateShortcut("cmd+ab") == nil)
    }

    @Test func findsShortcutClashes() {
        let templates = [
            ReplyTemplate(id: "a", shortcut: TemplateShortcut("cmd+shift+1"), prompt: ""),
            ReplyTemplate(id: "b", shortcut: TemplateShortcut("cmd+shift+1"), prompt: ""),
            ReplyTemplate(id: "c", shortcut: TemplateShortcut("cmd+shift+r"), prompt: ""),
            ReplyTemplate(id: "d", shortcut: TemplateShortcut("cmd+shift+2"), prompt: ""),
            ReplyTemplate(id: "e", prompt: ""),
        ]
        let problems = ReplyTemplate.shortcutProblems(in: templates)
        #expect(Set(problems.keys) == ["a", "b", "c"])
        #expect(problems["c"]?.contains("Triamail") == true)
    }

    @Test func savesRenamesAndDeletes() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = SettingsStore(folder: folder)
        var template = try store.save(ReplyTemplate(id: "", title: "Répondre à l'été", prompt: "Bonjour"))
        #expect(template.id == "repondre-a-l-ete")
        // Same title for another template: a distinct file.
        let twin = try store.save(ReplyTemplate(id: "", title: "Répondre à l'été", prompt: "Autre"))
        #expect(twin.id == "repondre-a-l-ete-2")
        template.title = "Relancer"
        template = try store.save(template)
        #expect(template.id == "relancer")
        #expect(try store.templates().map(\.id) == ["relancer", "repondre-a-l-ete-2"])
        #expect(try store.templates().first?.prompt == "Bonjour")
        try store.deleteTemplate(id: twin.id)
        #expect(try store.templates().map(\.id) == ["relancer"])
    }

    @Test func installAddsFrontMatterToOldCopiesAndKeepsTheirPrompt() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let bundled = root.appendingPathComponent("bundle")
        try FileManager.default.createDirectory(at: bundled, withIntermediateDirectories: true)
        try "---\ntitre: Répondre\nraccourci: cmd+shift+1\n---\nPrompt livré".write(to: bundled.appendingPathComponent("repondre.md"), atomically: true, encoding: .utf8)
        try "---\ntitre: Nouveau\n---\nAutre".write(to: bundled.appendingPathComponent("nouveau.md"), atomically: true, encoding: .utf8)
        let store = SettingsStore(folder: root.appendingPathComponent("reglages"))
        try FileManager.default.createDirectory(at: store.templatesFolder, withIntermediateDirectories: true)
        // A copy from an older version, edited by the user, without front matter.
        try "Mon prompt à moi".write(to: store.templatesFolder.appendingPathComponent("repondre.md"), atomically: true, encoding: .utf8)

        try store.installTemplates(from: bundled)
        var templates = try store.templates()
        #expect(templates.map(\.id) == ["nouveau", "repondre"])
        #expect(templates[1].title == "Répondre")
        #expect(templates[1].shortcut == TemplateShortcut("cmd+shift+1"))
        #expect(templates[1].prompt == "Mon prompt à moi")

        // Once it has front matter, the user's choices win (here: no shortcut).
        templates[1].shortcut = nil
        try store.save(templates[1])
        try store.installTemplates(from: bundled)
        #expect(try store.templates()[1].shortcut == nil)
    }

    @Test func readsWindowsLineEndings() {
        let template = ReplyTemplate(id: "x", contents: "---\r\ntitre: Relance\r\nraccourci: cmd+shift+5\r\n---\r\nBonjour")
        #expect(template.title == "Relance")
        #expect(template.shortcut == TemplateShortcut("cmd+shift+5"))
        #expect(template.prompt == "Bonjour")
    }

    @Test func savingWithTheSameTitleKeepsTheFileName() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = SettingsStore(folder: folder)
        try FileManager.default.createDirectory(at: store.templatesFolder, withIntermediateDirectories: true)
        try "---\ntitre: Renvoyer vers le support\n---\nTexte".write(to: store.templatesFolder.appendingPathComponent("renvoyer-vers-support.md"), atomically: true, encoding: .utf8)
        try "Mon texte".write(to: store.templatesFolder.appendingPathComponent("Relance.md"), atomically: true, encoding: .utf8)
        var support = try #require(try store.templates().first { $0.id == "renvoyer-vers-support" })
        support.icon = "lifepreserver"
        #expect(try store.save(support).id == "renvoyer-vers-support")
        // Only the case differs from the slug: same file on the Mac's disk, kept as it is.
        var relance = try #require(try store.templates().first { $0.id == "Relance" })
        relance.title = "relance"
        #expect(try store.save(relance).id == "Relance")
        #expect(try store.templates().map(\.id).sorted() == ["Relance", "renvoyer-vers-support"])
    }

    @Test func deletedBundledTemplatesDoNotComeBack() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let bundled = root.appendingPathComponent("bundle")
        try FileManager.default.createDirectory(at: bundled, withIntermediateDirectories: true)
        try "Texte".write(to: bundled.appendingPathComponent("loufoque.md"), atomically: true, encoding: .utf8)
        let store = SettingsStore(folder: root.appendingPathComponent("reglages"))
        try store.installTemplates(from: bundled)
        try store.deleteTemplate(id: "loufoque")
        try store.installTemplates(from: bundled)
        #expect(try store.templates().isEmpty)
    }

    @Test func oldSettingsHaveAnEmptyProfile() throws {
        let settings = try JSONDecoder().decode(SharedSettings.self, from: Data(#"{"version":1}"#.utf8))
        #expect(settings.profile == Profile())
    }
}

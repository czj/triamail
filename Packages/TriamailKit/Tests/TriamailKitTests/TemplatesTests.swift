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

    @Test func oldSettingsHaveAnEmptyProfile() throws {
        let settings = try JSONDecoder().decode(SharedSettings.self, from: Data(#"{"version":1}"#.utf8))
        #expect(settings.profile == Profile())
    }
}

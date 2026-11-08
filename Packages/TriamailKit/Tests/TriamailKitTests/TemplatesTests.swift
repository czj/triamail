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

    @Test func oldSettingsHaveAnEmptyProfile() throws {
        let settings = try JSONDecoder().decode(SharedSettings.self, from: Data(#"{"version":1}"#.utf8))
        #expect(settings.profile == Profile())
    }
}

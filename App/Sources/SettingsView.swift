import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("Comptes", systemImage: "person.crop.circle") {
                placeholder("Comptes Gmail", "La connexion à Gmail arrive dans une prochaine version.")
            }
            Tab("Archivage", systemImage: "folder") {
                placeholder("Dossiers et règles", "Les dossiers locaux et les règles de rangement arrivent dans une prochaine version.")
            }
            Tab("IA", systemImage: "sparkles") {
                placeholder("Modèles d'IA", "Modèle local de macOS ou API Mistral.")
            }
        }
        .frame(width: 520, height: 320)
    }

    private func placeholder(_ title: LocalizedStringKey, _ message: LocalizedStringKey) -> some View {
        ContentUnavailableView(title, systemImage: "hammer", description: Text(message))
    }
}

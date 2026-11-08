import SwiftUI
import TriamailKit

/// Settings > Profile: who the replies speak for (the `{profil.…}` variables of the templates).
struct ProfileSettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Form {
            Section {
                TextField("Prénom", text: $model.settings.profile.firstName)
                TextField("Nom complet", text: $model.settings.profile.fullName)
                TextField("Fonction", text: $model.settings.profile.role, prompt: Text("gérant, directeur technique…"))
                TextField("Entreprise principale", text: $model.settings.profile.company)
                TextField("Téléphone", text: $model.settings.profile.phone)
                TextField("Site web", text: $model.settings.profile.website)
                TextField("Page de contact du support", text: $model.settings.profile.supportURL)
                TextField("Entreprises (noms, raison sociale, activité)", text: $model.settings.profile.companies, axis: .vertical)
                    .lineLimit(3...8)
            } header: {
                Text("Profil")
            } footer: {
                Text("Ces informations remplacent les variables {profil.…} des modèles de réponse. Elles restent dans ton dossier de réglages.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

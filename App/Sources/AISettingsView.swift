import SwiftUI
import TriamailKit

/// Settings > AI: the Mac's own model, or Mistral with its key in the keychain.
struct AISettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var mistralKey = ""
    @State private var message: String?

    var body: some View {
        @Bindable var model = model
        Form {
            Section {
                Picker("Modèle", selection: $model.settings.aiProvider) {
                    Text("Modèle local de macOS").tag(AIProvider.appleLocal)
                    Text("Mistral (API)").tag(AIProvider.mistral)
                }
                .pickerStyle(.radioGroup)
                LabeledContent("Modèle local", value: AIService.localModelStatus)
            } footer: {
                Text("Le modèle local garde tout sur le Mac. Avec Mistral, le fil du mail est envoyé à Mistral pour rédiger.")
                    .foregroundStyle(.secondary)
            }
            Section("Mistral") {
                SecureField("Clé d'API", text: $mistralKey)
                TextField("Modèle", text: $model.settings.mistralModel, prompt: Text(MistralClient.defaultModel))
                Button("Enregistrer la clé dans le trousseau") {
                    do {
                        try Keychain.set(mistralKey.trimmingCharacters(in: .whitespacesAndNewlines), for: MistralClient.keychainAccount)
                        message = "Clé enregistrée dans le trousseau de ce Mac."
                    } catch {
                        message = error.localizedDescription
                    }
                }
                .disabled(mistralKey.isEmpty)
                if let message { Text(message).font(.caption).foregroundStyle(.secondary) }
            }
        }
        .formStyle(.grouped)
        .onAppear { mistralKey = MistralClient.storedKey() ?? "" }
        .onChange(of: model.settings.aiProvider) { model.save() }
        .onChange(of: model.settings.mistralModel) { model.save() }
    }
}

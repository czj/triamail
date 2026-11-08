import SwiftUI
import TriamailKit

/// The toolbar's account menu: connected accounts, then "Ajouter un compte Google".
struct AccountMenu: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Menu("Comptes", systemImage: "person.crop.circle") {
            if !model.accounts.isEmpty {
                Section("Comptes connectés") {
                    ForEach(model.accounts) { account in
                        Text(account.email)
                    }
                }
            }
            Button(model.signingIn ? "Connexion dans le navigateur…" : "Ajouter un compte Google…", systemImage: "plus") {
                model.addGoogleAccount()
            }
            .disabled(model.signingIn)
            SettingsLink { Text("Gérer les comptes…") }
        }
        .help("Comptes Google")
    }
}

/// Asked once, before the first sign-in: the OAuth client the user created in the Google Cloud console.
/// Sign-in continues as soon as it is saved.
struct OAuthClientSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var clientID = ""
    @State private var clientSecret = ""
    @State private var error: String?

    var body: some View {
        Form {
            Section {
                TextField("Identifiant client", text: $clientID, prompt: Text("….apps.googleusercontent.com"))
                SecureField("Code secret du client", text: $clientSecret)
            } header: {
                Text("Application Google (OAuth)")
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    OAuthClientHelp()
                    if let error {
                        Text(error).foregroundStyle(.red)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Enregistrer et se connecter") {
                    do {
                        try GmailAuthenticator().saveClient(id: clientID, secret: clientSecret)
                        dismiss()
                        Task { await model.signIn() }
                    } catch {
                        self.error = error.localizedDescription
                    }
                }
                .disabled(clientID.isEmpty || clientSecret.isEmpty)
            }
        }
    }
}

/// How to get an OAuth client, under the client fields (sheet and Settings > Comptes).
struct OAuthClientHelp: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Crée un identifiant « Application de bureau » dans la console Google Cloud, avec l'API Gmail activée, puis colle-le ici. Il reste dans le trousseau.")
            Link("Ouvrir la console Google Cloud", destination: URL(string: "https://console.cloud.google.com/apis/credentials")!)
        }
        .foregroundStyle(.secondary)
    }
}

import SwiftUI
import TriamailKit

/// "Ajouter un compte Google": asks for the OAuth client first when none is saved, then signs in.
/// The sheet belongs to the window that shows the button.
struct AddGoogleAccountButton: View {
    @Environment(AppModel.self) private var model
    @State private var askingClient = false

    var body: some View {
        Button("Ajouter un compte Google…", systemImage: "plus") {
            if !model.addGoogleAccount() { askingClient = true }
        }
        .sheet(isPresented: $askingClient) { OAuthClientSheet() }
    }
}

/// The toolbar's account menu: connected accounts, then "Ajouter un compte Google".
struct AccountMenu: View {
    @Environment(AppModel.self) private var model
    /// On the menu itself, not on its item: a menu item's sheet would close with the menu.
    @State private var askingClient = false

    var body: some View {
        Menu("Comptes", systemImage: "person.crop.circle") {
            if !model.accounts.isEmpty {
                Section("Comptes connectés") {
                    ForEach(model.accounts) { Text($0.email) }
                }
            }
            Button("Ajouter un compte Google…", systemImage: "plus") {
                if !model.addGoogleAccount() { askingClient = true }
            }
            SettingsLink { Text("Gérer les comptes…") }
        }
        .help("Comptes Google")
        .sheet(isPresented: $askingClient) { OAuthClientSheet() }
    }
}

/// Asked once, before the first sign-in: the OAuth client the user created in the Google Cloud console.
/// Sign-in starts as soon as it is saved.
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
                        if model.addGoogleAccount() { dismiss() } else { error = "Identifiant ou code secret vide." }
                    } catch {
                        self.error = error.localizedDescription
                    }
                }
                .disabled(clientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                          || clientSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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

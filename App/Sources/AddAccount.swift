import SwiftUI
import TriamailKit

/// "Ajouter un compte Google": signs in, or first asks for the OAuth client when none is saved yet.
/// The sheet hangs on the button, so it belongs to its window only. Not for a menu item: its sheet would close with the menu.
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

/// Asked once, before the first sign-in: the OAuth client the user created in the Google Cloud console.
/// Sign-in starts as soon as it is saved.
private struct OAuthClientSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var clientID = ""
    @State private var clientSecret = ""
    @State private var error: String?

    var body: some View {
        Form {
            OAuthClientFields(clientID: $clientID, clientSecret: $clientSecret, message: error)
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Enregistrer et se connecter") {
                    do {
                        try GmailAuthenticator().saveClient(id: clientID, secret: clientSecret)
                        // False: only spaces were pasted (saveClient trims them).
                        if model.addGoogleAccount() { dismiss() } else { error = "Identifiant ou code secret vide." }
                    } catch {
                        self.error = error.localizedDescription
                    }
                }
                .disabled(clientID.isEmpty || clientSecret.isEmpty)
            }
        }
    }
}

/// The OAuth client fields, with how to get one: the first-sign-in sheet and Settings > Comptes.
struct OAuthClientFields<Actions: View>: View {
    @Binding var clientID: String
    @Binding var clientSecret: String
    var message: String?
    @ViewBuilder var actions: Actions

    init(clientID: Binding<String>, clientSecret: Binding<String>, message: String?, @ViewBuilder actions: () -> Actions = { EmptyView() }) {
        _clientID = clientID
        _clientSecret = clientSecret
        self.message = message
        self.actions = actions()
    }

    var body: some View {
        Section {
            TextField("Identifiant client", text: $clientID, prompt: Text("….apps.googleusercontent.com"))
            SecureField("Code secret du client", text: $clientSecret)
            actions
        } header: {
            Text("Application Google (OAuth)")
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                Text("Crée un identifiant « Application de bureau » dans la console Google Cloud, avec l'API Gmail activée, puis colle-le ici. Il reste dans le trousseau.")
                Link("Ouvrir la console Google Cloud", destination: URL(string: "https://console.cloud.google.com/apis/credentials")!)
                if let message {
                    Text(message)
                }
            }
            .foregroundStyle(.secondary)
        }
    }
}

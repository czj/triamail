import SwiftUI
import TriamailKit

/// Settings > Accounts: the Google OAuth client (typed by the user) and the connected Gmail accounts.
struct AccountsSettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var clientID = ""
    @State private var clientSecret = ""
    /// Feedback on the OAuth client fields; the sign-in's own outcome is `model.signInMessage`.
    @State private var message: String?
    /// Read from the keychain on appear and after saving, not on every render.
    @State private var hasClient = false

    private let authenticator = GmailAuthenticator()

    var body: some View {
        Form {
            Section {
                ForEach(model.accounts) { account in
                    HStack {
                        Label(account.email, systemImage: "envelope")
                        Spacer()
                        Button("Déconnecter") { model.removeAccount(account) }
                    }
                }
                Button(model.signingIn ? "Connexion dans le navigateur…" : "Ajouter un compte Google…", systemImage: "plus") {
                    Task { await model.signIn() }
                }
                .disabled(model.signingIn || !hasClient)
            } header: {
                Text("Comptes Gmail")
            } footer: {
                if let message = model.signInMessage {
                    Text(message).foregroundStyle(.secondary)
                }
            }

            Section {
                TextField("Identifiant client", text: $clientID, prompt: Text("….apps.googleusercontent.com"))
                SecureField("Code secret du client", text: $clientSecret)
                Button("Enregistrer dans le trousseau") {
                    do {
                        try authenticator.saveClient(id: clientID, secret: clientSecret)
                        hasClient = true
                        message = "Identifiant enregistré dans le trousseau de ce Mac."
                    } catch {
                        message = error.localizedDescription
                    }
                }
                .disabled(clientID.isEmpty || clientSecret.isEmpty)
            } header: {
                Text("Application Google (OAuth)")
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    OAuthClientHelp()
                    if let message {
                        Text(message).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            clientID = authenticator.clientID ?? ""
            clientSecret = authenticator.clientSecret ?? ""
            hasClient = authenticator.client != nil
        }
    }
}

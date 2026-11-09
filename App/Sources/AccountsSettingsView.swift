import SwiftUI
import TriamailKit

/// Settings > Accounts: the Google OAuth client (typed by the user) and the connected Gmail accounts.
struct AccountsSettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var clientID = ""
    @State private var clientSecret = ""
    /// Feedback on the OAuth client fields; the sign-in's own outcome is `model.signInMessage`.
    @State private var message: String?

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
                AddGoogleAccountButton()
            } header: {
                Text("Comptes Gmail")
            } footer: {
                if let message = model.signInMessage {
                    Text(message).foregroundStyle(.secondary)
                }
            }

            OAuthClientFields(clientID: $clientID, clientSecret: $clientSecret, message: message) {
                Button("Enregistrer dans le trousseau") {
                    do {
                        try authenticator.saveClient(id: clientID, secret: clientSecret)
                        message = "Identifiant enregistré dans le trousseau de ce Mac."
                    } catch {
                        message = error.localizedDescription
                    }
                }
                .disabled(clientID.isEmpty || clientSecret.isEmpty)
            }
        }
        .formStyle(.grouped)
        // Again on each sign-in attempt: the client may have just been pasted in a sheet.
        .task(id: model.signInMessage) {
            clientID = authenticator.clientID ?? ""
            clientSecret = authenticator.clientSecret ?? ""
        }
    }
}

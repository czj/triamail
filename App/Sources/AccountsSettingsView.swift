import AppKit
import SwiftUI
import TriamailKit

/// Settings > Accounts: the Google OAuth client (typed by the user) and the connected Gmail accounts.
struct AccountsSettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var clientID = ""
    @State private var clientSecret = ""
    @State private var signingIn = false
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
                Button(signingIn ? "Connexion dans le navigateur…" : "Connecter un compte Gmail…", systemImage: "plus") {
                    signIn()
                }
                .disabled(signingIn || authenticator.client == nil)
            } header: {
                Text("Comptes Gmail")
            } footer: {
                if let message {
                    Text(message).foregroundStyle(.secondary)
                }
            }

            Section {
                TextField("Identifiant client", text: $clientID, prompt: Text("….apps.googleusercontent.com"))
                SecureField("Code secret du client", text: $clientSecret)
                Button("Enregistrer dans le trousseau") {
                    do {
                        try authenticator.saveClient(id: clientID, secret: clientSecret)
                        message = "Identifiant enregistré dans le trousseau de ce Mac."
                    } catch {
                        message = error.localizedDescription
                    }
                }
                .disabled(clientID.isEmpty || clientSecret.isEmpty)
            } header: {
                Text("Application Google (OAuth)")
            } footer: {
                Text("Crée un identifiant « Application de bureau » dans la console Google Cloud, avec l'API Gmail activée, puis colle-le ici. Il reste dans le trousseau.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            clientID = authenticator.clientID ?? ""
            clientSecret = authenticator.clientSecret ?? ""
        }
    }

    private func signIn() {
        signingIn = true
        message = nil
        Task {
            defer { signingIn = false }
            do {
                let account = try await authenticator.signIn { url in
                    await MainActor.run { _ = NSWorkspace.shared.open(url) }
                }
                model.addAccount(account)
                message = "\(account.email) est connecté."
            } catch {
                message = error.localizedDescription
            }
        }
    }
}

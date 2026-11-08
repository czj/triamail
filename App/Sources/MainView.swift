import SwiftUI

/// The three columns: mailboxes, mails to triage, and the action panel on the right.
struct MainView: View {
    @State private var selection: Mailbox? = .toTriage

    var body: some View {
        NavigationSplitView {
            List(Mailbox.allCases, selection: $selection) { mailbox in
                Label(mailbox.title, systemImage: mailbox.symbol)
                    .tag(mailbox)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } content: {
            ContentUnavailableView {
                Label("Aucun compte connecté", systemImage: "envelope.badge.shield.half.filled")
            } description: {
                Text("Connecte un compte Gmail dans les réglages pour voir les mails à traiter.")
            } actions: {
                SettingsLink {
                    Text("Ouvrir les réglages")
                }
            }
            .navigationSplitViewColumnWidth(min: 280, ideal: 340)
        } detail: {
            ContentUnavailableView("Aucun mail sélectionné", systemImage: "sidebar.right")
        }
        .navigationTitle(selection?.title ?? "Triamail")
    }
}

enum Mailbox: String, CaseIterable, Identifiable {
    case toTriage, github, invoices, direct

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .toTriage: "À traiter"
        case .github: "GitHub"
        case .invoices: "Factures et commandes"
        case .direct: "Pour moi"
        }
    }

    var symbol: String {
        switch self {
        case .toTriage: "tray"
        case .github: "chevron.left.forwardslash.chevron.right"
        case .invoices: "doc.text"
        case .direct: "person"
        }
    }
}

#Preview {
    MainView()
}

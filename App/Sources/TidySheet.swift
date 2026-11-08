import SwiftUI
import TriamailKit

/// The "Tidy" button's sheet: what will move, then one confirmation.
struct TidySheet: View {
    let settings: SharedSettings
    @Environment(\.dismiss) private var dismiss
    @State private var moves: [TidyMove] = []
    @State private var excluded: Set<URL> = []
    @State private var result: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ranger").font(.title2.weight(.semibold))
            if settings.tidySourcePaths.isEmpty {
                ContentUnavailableView("Aucun dossier à ranger", systemImage: "folder.badge.questionmark",
                                       description: Text("Ajoute Téléchargements, Bureau ou ton dossier de scans dans Réglages > Archivage."))
            } else if moves.isEmpty {
                ContentUnavailableView("Rien à ranger", systemImage: "checkmark.circle",
                                       description: Text(result ?? "Aucun fichier ne correspond aux règles."))
            } else {
                List(moves) { move in
                    Toggle(isOn: Binding(get: { !excluded.contains(move.source) },
                                         set: { if $0 { excluded.remove(move.source) } else { excluded.insert(move.source) } })) {
                        VStack(alignment: .leading) {
                            Text(move.source.lastPathComponent)
                            Text("→ \(move.plan.destination.path.abbreviatingHomeDirectory)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            HStack {
                if let result { Text(result).font(.caption).foregroundStyle(.secondary) }
                Spacer()
                Button("Fermer") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Ranger \(moves.count - excluded.count) fichier(s)") { tidy() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(moves.count == excluded.count)
            }
        }
        .padding()
        .frame(width: 620, height: 460)
        .task { refresh() }
    }

    private var tidier: FolderTidier {
        FolderTidier(planner: ArchivePlanner(folders: settings.archiveFolders, rules: settings.archiveRules),
                     sourceFolders: settings.tidySourcePaths.map(\.expandingTildeURL))
    }

    private func refresh() {
        moves = tidier.plan()
        excluded = []
    }

    private func tidy() {
        do {
            let done = try FolderTidier.apply(moves.filter { !excluded.contains($0.source) })
            result = "\(done.count) fichier(s) rangé(s)."
            refresh()
        } catch {
            result = "Échec : \(error.localizedDescription)"
        }
    }
}

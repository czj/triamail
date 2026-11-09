import SwiftUI
import TriamailKit

/// What the "Mail" menu can do with the mail in front (set by `MessageDetailView`).
struct MailActions {
    var markDone: () -> Void
    var reply: (ReplyTemplate) -> Void
    var summarize: () -> Void
    var remind: (ReminderDelay) -> Void
    /// Nil when the mail is not a GitHub notification.
    var launchClaudeCode: (() -> Void)?
    /// Nil when the mail links nowhere.
    var openInBrowser: (() -> Void)?
}

extension FocusedValues {
    @Entry var mailActions: MailActions?
    /// "Ranger" for the window in front, with or without a mail selected.
    @Entry var tidy: (() -> Void)?
}

/// The "Mail" menu: every action on the mail in front, with its shortcut, including one per reply template.
struct MailCommands: Commands {
    let model: AppModel
    @FocusedValue(\.mailActions) private var actions
    @FocusedValue(\.tidy) private var tidy

    var body: some Commands {
        CommandMenu("Mail") {
            Button("Traité") { actions?.markDone() }
                .keyboardShortcut("e")
                .disabled(actions == nil)
            Menu("Répondre") {
                ForEach(model.templates) { template in
                    // A shortcut that clashes (Settings > Modèles shows why) is not bound.
                    let shortcut = model.shortcutProblems[template.id] == nil ? template.shortcut : nil
                    Button(template.label) { actions?.reply(template) }
                        .keyboardShortcut(shortcut?.keyboardShortcut)
                }
            }
            .disabled(actions == nil || model.templates.isEmpty)
            Menu("Rappel") {
                ReminderPresetItems { actions?.remind($0) }
            }
            .disabled(actions == nil)
            Divider()
            Button("Résumer") { actions?.summarize() }
                .keyboardShortcut("y", modifiers: [.command, .shift])
                .disabled(actions == nil)
            Button("Ouvrir Claude Code") { actions?.launchClaudeCode?() }
                .keyboardShortcut("k", modifiers: [.command, .shift])
                .disabled(actions?.launchClaudeCode == nil)
            Button("Ouvrir dans le navigateur") { actions?.openInBrowser?() }
                .disabled(actions?.openInBrowser == nil)
            Divider()
            Button("Ranger Téléchargements, Bureau et scans…") { tidy?() }
                .disabled(tidy == nil)
        }
    }
}

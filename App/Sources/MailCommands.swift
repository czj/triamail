import SwiftUI
import TriamailKit

/// What the "Mail" menu can do with the mail in front (set by `MessageDetailView`, nil while a sheet is open).
struct MailActions {
    var markDone: () -> Void
    var reply: (ReplyTemplate) -> Void
    var summarize: () -> Void
    var remind: (ReminderDelay) -> Void
    var chooseReminderDate: () -> Void
    /// Nil when the mail is not a GitHub notification.
    var launchClaudeCode: (() -> Void)? = nil
    /// Nil when the mail links nowhere.
    var openInBrowser: (() -> Void)? = nil
}

extension FocusedValues {
    @Entry var mailActions: MailActions?
}

/// The reply templates as menu items: the toolbar's "Répondre" menu and the "Mail" menu's.
/// A view, so the menus follow template edits (a `Commands` body does not reliably observe the model).
struct TemplateMenuItems: View {
    let model: AppModel
    /// Shortcuts are bound in the menu bar only: the toolbar menu shows the same items without them.
    var bindsShortcuts = false
    let action: (ReplyTemplate) -> Void

    var body: some View {
        let problems = model.shortcutProblems
        ForEach(model.templates) { template in
            // A shortcut that clashes (Settings > Modèles shows why) is not bound.
            let shortcut = bindsShortcuts && problems[template.id] == nil ? template.shortcut : nil
            Button(template.label, systemImage: template.icon ?? "sparkles") { action(template) }
                .keyboardShortcut(shortcut?.keyboardShortcut)
        }
        if model.templates.isEmpty {
            Text("Aucun modèle : ajoutes-en dans Réglages > Modèles")
        }
    }
}

/// The "Mail" menu: every action on the mail in front, with its shortcut, including one per reply template.
struct MailCommands: Commands {
    let model: AppModel
    @FocusedValue(\.mailActions) private var actions

    var body: some Commands {
        CommandMenu("Mail") {
            Button("Traité") { actions?.markDone() }
                .keyboardShortcut("e")
                .disabled(actions == nil)
            Menu("Répondre") {
                TemplateMenuItems(model: model, bindsShortcuts: true) { actions?.reply($0) }
            }
            .disabled(actions == nil)
            Menu("Rappel") {
                ReminderPresetItems { actions?.remind($0) }
                Divider()
                Button("Choisir une date…") { actions?.chooseReminderDate() }
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
        }
    }
}

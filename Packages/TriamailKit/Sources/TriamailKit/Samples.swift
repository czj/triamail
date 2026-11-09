import Foundation

extension SharedSettings {
    /// Demo settings, kept in `folder` (a temporary one): a fake profile, and an archive rule for the
    /// sample invoice that files it in `folder/Factures` and "sends" it to a fake accounting address.
    public static func demo(in folder: URL) -> SharedSettings {
        let invoices = ArchiveFolder(name: "Factures (démo)", path: folder.appendingPathComponent("Factures").path,
                                     accountingEmail: "comptabilite@exemple.com")
        var settings = SharedSettings(
            archiveFolders: [invoices],
            archiveRules: [ArchiveRule(senderContains: "commandes@exemple.com", folderID: invoices.id,
                                       renameTo: "Facture Boutique Exemple", sendToAccounting: true)]
        )
        settings.profile.firstName = "Jeanne"
        settings.profile.fullName = "Jeanne Exemple"
        settings.profile.company = "Exemple SAS"
        settings.profile.website = "https://exemple.com"
        return settings
    }
}

extension MailMessage {
    /// Fake mails for screenshots and UI work (`-demo` launch argument): never real data.
    public static var samples: [MailMessage] {
        let now = Date.now
        func mail(_ id: String, from: String, subject: String, minutes: Double, snippet: String, text: String,
                  listID: String? = nil, unread: Bool = false, html: String? = nil, attachments: [Attachment] = []) -> MailMessage {
            MailMessage(id: id, threadID: id, account: SampleMailSource.account.email, from: from, to: "Jeanne Exemple <\(SampleMailSource.account.email)>",
                        cc: "", subject: subject, date: now.addingTimeInterval(-minutes * 60), snippet: snippet, listID: listID,
                        labelIDs: unread ? ["UNREAD", "INBOX"] : ["INBOX"], plainText: text, html: html, attachments: attachments)
        }
        return [
            mail("demo-1", from: "Paul Exemple <paul@exemple.com>", subject: "Devis pour le site de l'association", minutes: 12,
                 snippet: "Bonjour Jeanne, pourriez-vous m'envoyer un devis pour la refonte du site avant vendredi ?",
                 text: "Bonjour Jeanne,\n\nPourriez-vous m'envoyer un devis pour la refonte du site avant vendredi ? Nous aimerions le présenter au bureau lundi.\n\nMerci d'avance,\nPaul", unread: true),
            mail("demo-2", from: "GitHub <notifications@github.com>", subject: "[exemple/projet] Fix the login redirect (PR #42)", minutes: 35,
                 snippet: "@relecteur approved these changes.",
                 text: "@relecteur approved these changes.\n\nView it on GitHub:\nhttps://github.com/exemple/projet/pull/42#pullrequestreview-1",
                 listID: "<projet.exemple.github.com>", unread: true),
            mail("demo-3", from: "Boutique Exemple <commandes@exemple.com>", subject: "Votre facture n° 2026-118", minutes: 90,
                 snippet: "Merci pour votre commande. Vous trouverez votre facture en pièce jointe.",
                 text: "Bonjour,\n\nMerci pour votre commande. Vous trouverez votre facture en pièce jointe.\n\nL'équipe Boutique Exemple",
                 attachments: [Attachment(fileName: "facture-2026-118.pdf", mimeType: "application/pdf", attachmentID: "a1", size: 48_000)]),
            mail("demo-4", from: "Anna Beispiel <anna@beispiel.exemple.com>", subject: "Frage zur Zusammenarbeit", minutes: 240,
                 snippet: "Hallo Jeanne, ich hätte eine Frage zu unserer Zusammenarbeit im nächsten Quartal.",
                 text: "Hallo Jeanne,\n\nich hätte eine Frage zu unserer Zusammenarbeit im nächsten Quartal. Hätten Sie nächste Woche Zeit für ein kurzes Gespräch?\n\nViele Grüße\nAnna", unread: true),
            mail("demo-5", from: "GitHub <notifications@github.com>", subject: "[exemple/outil] CI failed on main", minutes: 600,
                 snippet: "Run failed: build (macos-latest)",
                 text: "Run failed: build (macos-latest)\n\nhttps://github.com/exemple/outil/actions/runs/123",
                 listID: "<outil.exemple.github.com>"),
            mail("demo-6", from: "Marie Exemple <marie@exemple.org>", subject: "Re: Réunion de jeudi", minutes: 1500,
                 snippet: "Parfait pour 14 h, je réserve la salle.",
                 text: "Parfait pour 14 h, je réserve la salle.\n\nMarie"),
            // An HTML mail with a remote image: blocked until "Charger le contenu distant".
            mail("demo-7", from: "Atelier Exemple <atelier@exemple.com>", subject: "Votre inscription à l'atelier du 20 novembre", minutes: 45,
                 snippet: "Bonjour Jeanne, votre place est réservée. Voici le programme de la journée.",
                 text: "Bonjour Jeanne,\n\nVotre place est réservée. Voici le programme de la journée.",
                 unread: true,
                 html: """
                 <div style="max-width:560px;margin:auto;font-family:-apple-system,sans-serif">
                 <img src="https://exemple.com/bandeau.png" alt="Atelier Exemple" width="560" height="120" style="display:block;background:#e8eefc">
                 <h1 style="color:#2a4bd7;font-size:22px">Votre place est réservée</h1>
                 <p>Bonjour Jeanne,</p>
                 <p>Merci pour votre inscription à l'atelier du <b>20 novembre</b>. Voici le programme :</p>
                 <table style="border-collapse:collapse;width:100%">
                 <tr><td style="padding:6px;border-bottom:1px solid #ddd">9 h 30</td><td style="padding:6px;border-bottom:1px solid #ddd">Accueil</td></tr>
                 <tr><td style="padding:6px;border-bottom:1px solid #ddd">10 h</td><td style="padding:6px;border-bottom:1px solid #ddd">Atelier pratique</td></tr>
                 <tr><td style="padding:6px">12 h 30</td><td style="padding:6px">Déjeuner</td></tr>
                 </table>
                 <p><a href="https://exemple.com/atelier" style="display:inline-block;padding:10px 16px;background:#2a4bd7;color:#fff;border-radius:6px;text-decoration:none">Voir le détail</a></p>
                 <p style="color:#888;font-size:12px">Atelier Exemple · exemple.com</p>
                 </div>
                 """),
        ]
    }
}

# Triamail

A macOS mail client for triaging email and acting on it, without leaving the list:

- a native mail layout: a sidebar with the mailboxes (to triage, GitHub, invoices, for me; ⌘1…⌘4 in the "Boîte" menu, with the number of mails left to triage) and the connected accounts, the mail list (sender avatars, compact dates; hover, right-click or swipe to archive or set a reminder without opening the mail), the mail (HTML as sent, without JavaScript, remote images blocked until "Charger", links opened in the browser), and on the right the notification's page (GitHub…) or the invoice PDF (⌥⌘0 to hide it);
- launch a Claude Code session on the linked repository;
- draft an AI reply from a template, saved as a draft: the toolbar's "Répondre" menu and the menu bar's "Mail" menu list the templates with their shortcuts, templates edited in Réglages > Modèles;
- a short toolbar (Traité, Répondre, Rappel, "…" for Résumer, Claude Code and the browser; Ranger for the window) and a "Mail" menu with every mail action and its shortcut;
- create a reminder (D+1, D+3, D+7 or a chosen date) in the Reminders app;
- archive an invoice (rename, file, forward to accounting);
- automatically translate foreign-language emails, locally;
- summarize an email or a whole thread;
- tidy Downloads, Desktop and scans with the same rules as invoices.

Triamail sits next to a regular mail client: it is for triage, not for reading.

The app's interface is in French.

**Status**: every feature of the first roadmap is in; the app has not yet been proven in daily use.

## Getting started

1. **Gmail**: in the Google Cloud console, create a project, enable the Gmail API, create a "Desktop app" OAuth client ID, then publish the consent screen to production. Then click "Ajouter un compte Google" (Add a Google account) in the empty mail list or in the sidebar's "Comptes" section: the first time, the app asks for the client ID and its secret (they go into the keychain), then opens Google's sign-in. Réglages > Comptes (Settings > Accounts) lists and disconnects accounts.
2. **Settings**: the settings folder (in iCloud Drive by default) holds `reglages.json` and the reply templates; it is shared between your Macs.
3. **Archiving**: declare your local folders and your rules in Réglages > Archivage (Settings > Archiving).
4. **AI**: macOS's local model (Apple Intelligence) or a Mistral key, in Réglages > IA (Settings > AI).

## Install

Requires macOS 26 (Tahoe) or later.

- **Homebrew**:

  ```bash
  brew tap czj/triamail https://github.com/czj/triamail
  brew install --cask triamail
  ```

- **Manually**: download [`Triamail.dmg`](https://github.com/czj/triamail/releases/latest/download/Triamail.dmg), open it and drag Triamail into Applications. Until releases are notarized by Apple, macOS blocks the first launch: System Settings > Privacy & Security > "Open Anyway".

After that, the app updates itself (Triamail > Rechercher les mises à jour…, i.e. Check for Updates).

## Publishing a release

Everything starts from the commit messages (Conventional Commits):

1. on every merge to `main`, release-please keeps a "chore(main): release x.y.z" PR up to date with the changelog;
2. merging that PR creates the tag and the GitHub release; the `Release` workflow then builds the app on macOS and attaches `Triamail.dmg`, `Triamail.zip` and the `appcast.xml` update feed.

To try the packaging without publishing: Actions > Release > Run workflow (on any branch); the DMG is attached to the run. Locally: `scripts/package.sh 0.1.0`.

Repository settings (Settings > Secrets and variables > Actions):

| Name | Type | Purpose |
| --- | --- | --- |
| `SPARKLE_PUBLIC_KEY` | variable | EdDSA public key, embedded in the app |
| `SPARKLE_PRIVATE_KEY` | secret | signs the update feed |
| `DEVELOPER_ID_CERTIFICATE` | secret | optional: "Developer ID Application" certificate exported as `.p12`, base64-encoded (`base64 -i cert.p12 \| pbcopy`) |
| `DEVELOPER_ID_CERTIFICATE_PASSWORD` | secret | password of the `.p12` |
| `APPLE_ID`, `APPLE_APP_PASSWORD`, `APPLE_TEAM_ID` | secrets | notarization: Apple ID, app-specific password (appleid.apple.com), team ID |

The Sparkle keys are created once with Sparkle's `generate_keys` tool (`generate_keys -x private-key.txt` exports the private key). Without Sparkle keys, the app gets no updates; without a Developer ID, it is signed ad hoc (warning on first launch, except with Homebrew).

## Building

Requires macOS 26 or later, Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
brew install xcodegen
xcodegen generate
open Triamail.xcodeproj
```

The UI-free engine can be tested on its own: `swift test --package-path Packages/TriamailKit`.

Demo mode: launch with `-demo` (Xcode scheme > Arguments) to get a fake `exemple.com` account with sample mails kept in memory. Every action works (archive, invoice PDF, summary, reply draft) without a Google account, and the real accounts are not touched. Add `-demoSelection demo-2` to open on a given mail, for screenshots.

- `App/`: the SwiftUI app.
- `Packages/TriamailKit/`: the UI-free logic (archiving rules…), tested separately.
- `project.yml`: the Xcode project description, which XcodeGen turns into `Triamail.xcodeproj` (not versioned).
- `modeles/`: AI reply templates shipped with the app.
- `AGENTS.md`: instructions for agents working on the repository.

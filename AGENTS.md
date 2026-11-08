# Instructions for agents (Claude Code, etc.)

## Rule #1: no personal information in the repository

This repository is public. Never write into it:
- a real person's name, an email address, a phone number, a postal address;
- a real company name, a legal entity name, a SIRET/SIREN, a VAT number, an IBAN;
- the URL of a website or customer account tied to the user;
- an accounting recipient's address, a personal folder path, an account identifier;
- a secret: API key, OAuth token, password, OAuth client ID.

Instead:
- in reply templates, use the `{profil.…}` variables (see `modeles/README.md`);
- in code, read these values from the app's preferences (settings synced through iCloud Drive) or from the keychain for secrets;
- in tests and examples, use obviously fake values (`Jeanne Exemple`, `exemple.com`, `+33 1 23 45 67 89`).

Before every commit, read the diff looking for this kind of information. When in doubt, do not commit and ask.

## The project

Triamail is a native macOS client (SwiftUI) for triaging email and acting on it: a web panel on the right for notifications, launching Claude Code on the linked repository, AI replies from templates, reminders in the Reminders app, invoice archiving, local translation.

Principles:
- No background task that acts: every action starts from a user click. Only exceptions: language detection and local translation.
- Mail: Gmail API only for now.
- Claude Code: local only.
- AI: Apple's local model by default, Mistral API as an option.
- Nothing personal hard-coded: everything is set in the app. Shared settings: `reglages.json` and `modeles/` in an iCloud Drive folder (`SettingsStore`); secrets: keychain (`Keychain`).
- Roadmap: the issues numbered "Step n of N", handled in order, one PR per issue (`Closes #n`).
- Updates: Sparkle 2. The release publishes `appcast.xml`, EdDSA-signed with the `SPARKLE_PRIVATE_KEY` secret; the public key comes from the `SPARKLE_PUBLIC_KEY` repository variable. Without them, Sparkle stays off (local builds).
- Distribution: `scripts/package.sh` builds `Triamail.dmg` and the zips (Developer ID signing and notarization if the `DEVELOPER_ID_*` and `APPLE_*` secrets exist, ad hoc otherwise); the Homebrew cask `Casks/triamail.rb` always points at the latest release.

## Language
Everything used for development is in English: code, type names, comments, commit messages, PR titles and descriptions, issues, GitHub comments, documentation, workflows. Only the app's user-facing text (UI strings, the reply templates in `modeles/`) is in French.

## How to work
- Never commit directly to `main`: a branch, then a pull request, squash-merged. The `main` protection rule requires only the "CI passed" check.
- Before opening a PR: run `/code-review` then `/simplify` on the branch diff, fix what they find (or say in the PR why not), and only then push. Run both passes again after a large fix.
- Confident: open the PR as ready and enable auto-merge (`gh pr merge --auto --squash`); it merges as soon as CI is green. Not yet: a draft PR (it does not run CI), then `gh pr ready`.
- GitHub Actions are pinned by commit with the version in a comment; Dependabot proposes updates.
- Commit messages and PR titles follow Conventional Commits, in English: `feat: D+1, D+3, D+7 reminders`, `fix: …`, `docs: …`, `chore: …`. `feat` and `fix` appear in the changelog; `feat!` or `BREAKING CHANGE` triggers a major version.
- Do not edit `CHANGELOG.md` or version numbers by hand: release-please handles them on every merge to `main` (a "chore(main): release x.y.z" PR to merge in order to publish).
- The app builds on macOS only. In a Linux cloud session you cannot build: push and read the CI result (`gh run watch`).
- The Xcode project is generated from `project.yml` by XcodeGen: edit `project.yml`, never the `.xcodeproj` (not versioned). All testable logic goes into `Packages/TriamailKit`, with its tests (Swift Testing); the app keeps only the UI.
- Keep `README.md` up to date when a visible feature changes.

## Screenshots in PRs and issues
`gh` ≥ 2.99 uploads screenshots and videos itself: `--attach './capture.png#Alt text'` (repeatable) on `gh {issue,pr} {create,edit,comment}`. A `![alt](./capture.png)` already in the text is replaced by the uploaded URL; unreferenced files are appended at the end.

A PR that changes what is on screen shows each affected view before and after: before on the target branch, after on the PR branch. An issue describing a visible problem attaches a screenshot.

- On a Mac: `screencapture -o -l <window id> capture.png` (window only, no shadow), or the UI test screenshots (XCUITest).
- In a Linux cloud session the app does not run: take screenshots in the macOS CI (UI tests, attached to the run) or ask for them.
- Screenshots show only fake data: never a real email, a real name or a real address (see rule #1).
- When the change touches accessibility (VoiceOver labels, roles), add the accessibility tree diff: identical pixels prove nothing there.

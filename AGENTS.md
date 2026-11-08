# Consignes pour les agents (Claude Code, etc.)

## Règle n°1 : aucune information personnelle dans le dépôt

Ce dépôt est public. N'y écris jamais :
- un nom de personne réel, une adresse mail, un numéro de téléphone, une adresse postale ;
- un nom d'entreprise réel, une raison sociale, un SIRET/SIREN, un numéro de TVA, un IBAN ;
- l'URL d'un site ou d'un compte client lié à l'utilisateur ;
- une adresse de destinataire comptable, un chemin de dossier personnel, un identifiant de compte ;
- un secret : clé d'API, jeton OAuth, mot de passe, identifiant client OAuth.

À la place :
- dans les modèles de réponse, utilise les variables `{profil.…}` (voir `modeles/README.md`) ;
- dans le code, lis ces valeurs dans les préférences de l'app (réglages synchronisés par iCloud Drive) ou dans le trousseau pour les secrets ;
- dans les tests et exemples, utilise des valeurs fictives évidentes (`Jeanne Exemple`, `exemple.com`, `+33 1 23 45 67 89`).

Avant chaque commit, relis le diff en cherchant ce type d'information. En cas de doute, ne commite pas et demande.

## Le projet

Triamail est un client macOS natif (SwiftUI) pour trier les mails et agir dessus : panneau web à droite pour les notifications, lancement de Claude Code sur le dépôt lié, réponses IA à partir de modèles, rappels dans l'app Rappels, archivage des factures, traduction locale.

Principes :
- Aucune tâche de fond qui agit : chaque action part d'un clic de l'utilisateur. Seules exceptions : la détection de langue et la traduction locale.
- Mail : API Gmail uniquement pour l'instant.
- Claude Code : en local uniquement.
- IA : modèle local d'Apple par défaut, API Mistral en option.
- Rien de personnel en dur : tout se règle dans l'app. Réglages partagés : `reglages.json` et `modeles/` dans un dossier iCloud Drive (`SettingsStore`) ; secrets : trousseau (`Keychain`).
- Feuille de route : les issues numérotées « Étape n sur N », traitées dans l'ordre, une PR par issue (`Closes #n`).
- Mises à jour : Sparkle 2. La release publie `appcast.xml`, signé EdDSA avec le secret `SPARKLE_PRIVATE_KEY` ; la clé publique vient de la variable du dépôt `SPARKLE_PUBLIC_KEY`. Sans elles, Sparkle reste éteint (builds locaux).

## Langue
Le code, les noms de types et les commentaires sont en anglais ; la documentation et les textes de l'interface sont en français.

## Façon de travailler
- Jamais de commit direct sur `main` : une branche, puis une pull request, fusionnée en squash. La règle de protection de `main` exige le seul contrôle « CI passed ».
- Avant d'ouvrir une PR : lance `/code-review` puis `/simplify` sur le diff de la branche, corrige ce qu'ils trouvent (ou dis dans la PR pourquoi non), et seulement ensuite pousse. Les deux passes se refont après une grosse correction.
- Sûr de toi : ouvre la PR prête et active l'auto-merge (`gh pr merge --auto --squash`), elle fusionne dès que la CI est verte. Pas encore : une PR en brouillon (elle ne lance pas la CI), puis `gh pr ready`.
- Les actions GitHub sont épinglées par commit avec la version en commentaire ; Dependabot propose les mises à jour.
- Messages de commit et titres de PR au format Conventional Commits, type en anglais et description en français : `feat: rappels J+1, J+3, J+7`, `fix: …`, `docs: …`, `chore: …`. `feat` et `fix` apparaissent dans le changelog ; `feat!` ou `BREAKING CHANGE` déclenche une version majeure.
- Ne modifie pas `CHANGELOG.md` ni les numéros de version à la main : release-please s'en charge à chaque fusion sur `main` (PR « chore(main): release x.y.z » à fusionner pour publier).
- L'app se compile sur macOS uniquement. Dans une session cloud Linux, on ne peut pas compiler : pousse et lis le résultat de la CI (`gh run watch`).
- Le projet Xcode est généré depuis `project.yml` par XcodeGen : modifie `project.yml`, jamais le `.xcodeproj` (non versionné). Toute logique testable va dans `Packages/TriamailKit`, avec ses tests (Swift Testing) ; l'app ne garde que l'interface.
- Tiens `README.md` à jour quand une fonction visible change.

## Captures d'écran dans les PR et les issues
`gh` ≥ 2.99 envoie lui-même captures et vidéos : `--attach './capture.png#Texte alternatif'` (répétable) sur `gh {issue,pr} {create,edit,comment}`. Un `![alt](./capture.png)` déjà dans le texte est remplacé par l'URL envoyée ; les fichiers non référencés sont ajoutés à la fin.

Une PR qui change ce qu'on voit à l'écran montre chaque vue touchée avant et après : avant sur la branche cible, après sur la branche de la PR. Une issue qui décrit un problème visible joint une capture.

- Sur un Mac : `screencapture -o -l <id de fenêtre> capture.png` (fenêtre seule, sans ombre), ou les captures des tests d'interface (XCUITest).
- Dans une session cloud Linux, l'app ne tourne pas : prends les captures dans la CI macOS (tests d'interface, joints au run) ou demande-les.
- Les captures ne montrent que des données fictives : jamais un vrai mail, un vrai nom ni une vraie adresse (voir la règle n°1).
- Quand le changement touche l'accessibilité (libellés VoiceOver, rôles), ajoute le diff de l'arbre d'accessibilité : des pixels identiques n'y prouvent rien.

# Triamail

Client mail macOS pour trier les mails et agir dessus, sans quitter la liste :

- ouvrir la page d'une notification (GitHub…) dans un panneau à droite ;
- lancer une session Claude Code sur le dépôt lié ;
- préparer une réponse avec l'IA à partir d'un modèle, déposée en brouillon ;
- créer un rappel (J+1, J+3, J+7 ou date au choix) dans l'app Rappels ;
- archiver une facture (renommer, ranger, transmettre à la comptabilité) ;
- traduire automatiquement, en local, les mails en langue étrangère.

Triamail cohabite avec un client mail classique : il sert au tri, pas à la lecture.

**État** : la coque de l'app (fenêtre en trois colonnes, réglages) et le moteur des règles d'archivage. Rien n'est encore branché à Gmail.

## Compiler

Il faut macOS 26 ou plus récent, Xcode et [XcodeGen](https://github.com/yonaskolb/XcodeGen) :

```bash
brew install xcodegen
xcodegen generate
open Triamail.xcodeproj
```

Le moteur sans interface se teste seul : `swift test --package-path Packages/TriamailKit`.

- `App/` : l'app SwiftUI.
- `Packages/TriamailKit/` : la logique sans interface (règles d'archivage…), testée à part.
- `project.yml` : la description du projet Xcode, que XcodeGen transforme en `Triamail.xcodeproj` (non versionné).
- `modeles/` : modèles de réponse IA livrés avec l'app.
- `AGENTS.md` : consignes pour les agents qui travaillent sur le dépôt.

# Triamail

Client mail macOS pour trier les mails et agir dessus, sans quitter la liste :

- ouvrir la page d'une notification (GitHub…) dans un panneau à droite ;
- lancer une session Claude Code sur le dépôt lié ;
- préparer une réponse avec l'IA à partir d'un modèle, déposée en brouillon ;
- créer un rappel (J+1, J+3, J+7 ou date au choix) dans l'app Rappels ;
- archiver une facture (renommer, ranger, transmettre à la comptabilité) ;
- traduire automatiquement, en local, les mails en langue étrangère ;
- résumer un mail ou tout un fil ;
- ranger Téléchargements, Bureau et scans avec les mêmes règles que les factures.

Triamail cohabite avec un client mail classique : il sert au tri, pas à la lecture.

**État** : toutes les fonctions de la première feuille de route sont là ; l'app n'a pas encore été éprouvée au quotidien.

## Mise en route

1. **Gmail** : dans la console Google Cloud, crée un projet, active l'API Gmail, crée un identifiant OAuth « Application de bureau », puis passe l'écran de consentement en production. Colle l'identifiant et son code secret dans Réglages > Comptes (ils vont dans le trousseau), puis connecte tes comptes.
2. **Réglages** : le dossier de réglages (par défaut dans iCloud Drive) contient `reglages.json` et les modèles de réponse ; il se partage entre tes Mac.
3. **Archivage** : déclare tes dossiers locaux et tes règles dans Réglages > Archivage.
4. **IA** : modèle local de macOS (Apple Intelligence) ou clé Mistral, dans Réglages > IA.

## Mises à jour

Les releases GitHub publient l'app (signature ad hoc : au premier lancement, clic droit > Ouvrir) et, si le dépôt a la clé Sparkle, un flux de mises à jour signé que l'app consulte d'elle-même.

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

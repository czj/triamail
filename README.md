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

## Installer

Il faut macOS 26 (Tahoe) ou plus récent.

- **Homebrew** :

  ```bash
  brew tap czj/triamail https://github.com/czj/triamail
  brew install --cask triamail
  ```

- **À la main** : télécharge [`Triamail.dmg`](https://github.com/czj/triamail/releases/latest/download/Triamail.dmg), ouvre-le et glisse Triamail dans Applications. Tant que les releases ne sont pas notarisées par Apple, macOS bloque le premier lancement : Réglages Système > Confidentialité et sécurité > « Ouvrir quand même ».

Ensuite, l'app se met à jour d'elle-même (Triamail > Rechercher les mises à jour…).

## Publier une version

Tout part des messages de commit (Conventional Commits) :

1. à chaque fusion sur `main`, release-please tient à jour une PR « chore(main): release x.y.z » avec le changelog ;
2. fusionner cette PR crée le tag et la release GitHub ; le workflow `Release` y construit l'app sur macOS et joint `Triamail.dmg`, `Triamail.zip` et le flux de mises à jour `appcast.xml`.

Pour essayer l'empaquetage sans publier : Actions > Release > Run workflow (sur n'importe quelle branche) ; le DMG est joint au run. En local : `scripts/package.sh 0.1.0`.

Réglages du dépôt (Settings > Secrets and variables > Actions) :

| Nom | Type | Rôle |
| --- | --- | --- |
| `SPARKLE_PUBLIC_KEY` | variable | clé publique EdDSA, inscrite dans l'app |
| `SPARKLE_PRIVATE_KEY` | secret | signe le flux de mises à jour |
| `DEVELOPER_ID_CERTIFICATE` | secret | facultatif : certificat « Developer ID Application » exporté en `.p12`, en base64 (`base64 -i cert.p12 \| pbcopy`) |
| `DEVELOPER_ID_CERTIFICATE_PASSWORD` | secret | mot de passe du `.p12` |
| `APPLE_ID`, `APPLE_APP_PASSWORD`, `APPLE_TEAM_ID` | secrets | notarisation : identifiant Apple, mot de passe d'app (appleid.apple.com), identifiant d'équipe |

Les clés Sparkle se créent une fois avec l'outil `generate_keys` de Sparkle (`generate_keys -x cle-privee.txt` exporte la clé privée). Sans clés Sparkle, l'app n'a pas de mises à jour ; sans Developer ID, elle est signée ad hoc (avertissement au premier lancement, sauf avec Homebrew).

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

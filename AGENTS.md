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
- Mail : API Gmail d'abord, IMAP plus tard.
- IA : modèle local d'Apple par défaut, API Mistral en option.
- Rien de personnel en dur : tout se règle dans l'app.

## Langue
Le code, les noms de types et les commentaires sont en anglais ; la documentation et les textes de l'interface sont en français.

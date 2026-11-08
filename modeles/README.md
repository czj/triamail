# Modèles de réponse

Modèles livrés avec Triamail. Ils ne contiennent aucune information personnelle : l'app remplace les variables `{profil.…}` par ce que l'utilisateur saisit dans ses préférences.

| Fichier | Modèle | Champ demandé avant de rédiger |
|---|---|---|
| `repondre.md` | Répondre | « Intention et ton » |
| `renvoyer-vers-support.md` | Renvoyer vers le support | aucun |
| `dites-m-en-plus.md` | Dites-m'en plus | aucun |
| `loufoque.md` | Loufoque (réponse aux spams) | « Guidance » |
| `oubliez-moi.md` | Oubliez-moi | aucun |

## Variables

Remplies par l'app :
- `{selection}` : le fil complet du mail.
- `{argument name="…"}` : un champ demandé avant de rédiger.

Remplies depuis les préférences (profil) :
- `{profil.prenom}`, `{profil.nom_complet}`, `{profil.fonction}`
- `{profil.entreprise}` : l'entreprise principale
- `{profil.entreprises}` : la description des entreprises (noms commerciaux, raison sociale, activité)
- `{profil.telephone}`, `{profil.site_web}`, `{profil.url_support}`

La syntaxe `{selection}` / `{argument name="…"}` reprend celle des AI Commands de Raycast, pour pouvoir importer des prompts existants.

## À faire
- Ranger la partie commune (voix, signature, entreprises) dans un seul « profil de voix » : `repondre.md` et `renvoyer-vers-support.md` la répètent presque mot pour mot.
- Traduire `dites-m-en-plus.md` en français ; la réponse reste dans la langue du mail reçu.

# Reply templates

Templates shipped with Triamail. They contain no personal information: the app replaces the `{profil.…}` variables with what the user enters in their preferences. The templates themselves are user-facing content and stay in French.

| File | Template | Field asked before drafting |
|---|---|---|
| `repondre.md` | Répondre (Reply) | « Intention et ton » (intent and tone) |
| `renvoyer-vers-support.md` | Renvoyer vers le support (Redirect to support) | none |
| `dites-m-en-plus.md` | Dites-m'en plus (Tell me more) | none |
| `loufoque.md` | Loufoque (Zany: reply to spam) | « Guidance » |
| `oubliez-moi.md` | Oubliez-moi (Forget me) | none |

## Variables

Filled in by the app:
- `{selection}`: the full email thread.
- `{argument name="…"}`: a field asked before drafting.

Filled in from the preferences (profile):
- `{profil.prenom}`, `{profil.nom_complet}`, `{profil.fonction}`
- `{profil.entreprise}`: the main company
- `{profil.entreprises}`: the description of the companies (trade names, legal name, business)
- `{profil.telephone}`, `{profil.site_web}`, `{profil.url_support}`

The `{selection}` / `{argument name="…"}` syntax follows Raycast's AI Commands, so existing prompts can be imported.

## To do
- Move the shared part (voice, signature, companies) into a single "voice profile": `repondre.md` and `renvoyer-vers-support.md` repeat it almost word for word.
- Translate `dites-m-en-plus.md` into French; the reply stays in the language of the received email.

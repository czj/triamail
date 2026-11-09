# Reply templates

Templates shipped with Triamail. They contain no personal information: the app replaces the `{profil.…}` variables with what the user enters in their preferences. The templates themselves are user-facing content and stay in French.

| File | Template | Shortcut | Field asked before drafting |
|---|---|---|---|
| `repondre.md` | Répondre (Reply) | ⇧⌘1 | « Intention et ton » (intent and tone) |
| `renvoyer-vers-support.md` | Renvoyer vers le support (Redirect to support) | ⇧⌘2 | none |
| `dites-m-en-plus.md` | Dites-m'en plus (Tell me more) | ⇧⌘3 | none |
| `loufoque.md` | Loufoque (Zany: reply to spam) | none | « Guidance » |
| `oubliez-moi.md` | Oubliez-moi (Forget me) | ⇧⌘4 | none |

Each template is a button under the mail. They are edited in Réglages > Modèles (Settings > Templates), or by hand: the files live in the `modeles/` folder of the settings folder. The bundled files are copied there on first launch and never overwritten afterwards.

## Front matter

Optional, at the top of the file:

```
---
titre: Répondre
bouton: Répondre
raccourci: cmd+shift+1
icone: arrowshape.turn.up.left
---
prompt…
```

- `titre`: the name in Settings; the file name follows it. Without front matter, the title comes from the file name (`dites-m-en-plus` → "Dites m en plus").
- `bouton`: the button's label under the mail (the title when missing).
- `raccourci`: modifiers among `cmd`, `shift`, `option`, `control`, then one key. The app's own shortcuts (⌘E, ⌘S, ⌘R, ⇧⌘R, ⇧⌘Y, ⇧⌘K, ⌥⌘0, ⌘1…⌘4…) and duplicates are refused.
- `icone`: an SF Symbol name.

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

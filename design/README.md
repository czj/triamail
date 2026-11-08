# Icône

`icone.py` dessine l'icône de Triamail (enveloppe ouverte, trois mails triés, coche) sur la grille macOS : carré arrondi continu de 824 px sur une toile de 1024 px. Le dessin est fait en 4096 px puis réduit, pour des bords nets à toutes les tailles.

```bash
python3 design/icone.py   # → design/icone-1024.png
```

Les tailles de `App/Resources/Assets.xcassets/AppIcon.appiconset` (16 à 1024 px) sont tirées de `icone-1024.png`.

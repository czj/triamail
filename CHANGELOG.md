# Changelog

## [0.2.0](https://github.com/czj/triamail/compare/v0.1.0...v0.2.0) (2026-11-08)


### Features

* "To do" list fed by Gmail ([dd4fb54](https://github.com/czj/triamail/commit/dd4fb54a43b0bd5c8878b18b7ad59e835910f7cf))
* AI replies drafted in the background and saved as drafts (C3) ([ab8551a](https://github.com/czj/triamail/commit/ab8551a29a2a0d5eab64892d28e624c0d067070b))
* app shell and archiving rules engine ([30ad13c](https://github.com/czj/triamail/commit/30ad13cb145e9ac52ec136a7ab2423661c8c4a7a))
* archive an invoice in one click (C5) ([fce1920](https://github.com/czj/triamail/commit/fce19207e907afe767cf8cb892c4172f2b56e4b8))
* archiving folders and rules screen ([002564b](https://github.com/czj/triamail/commit/002564b0165565b3b926928d8fbdea2389f9e9e6))
* automatic updates with Sparkle ([0b54a4e](https://github.com/czj/triamail/commit/0b54a4e778b40a0ccd7bfbbd911bc541c42699b3))
* automatic, local translation of foreign-language emails (C6) ([6c0a1be](https://github.com/czj/triamail/commit/6c0a1be1c5e3557b41a632fcb8b414696515aa65))
* Gmail account sign-in (OAuth, PKCE, keychain) ([9e82ff0](https://github.com/czj/triamail/commit/9e82ff07d976fd0dfd91ec72753377fd2186116c))
* launch Claude Code on the notification's repository (C2) ([0a809a3](https://github.com/czj/triamail/commit/0a809a39867861c7268d121a9ed675065c8599bf))
* notification page in the right-hand panel (C1) ([6ea1273](https://github.com/czj/triamail/commit/6ea127343cd5895e597d42d5e7b27bb36e7b7fe9))
* profile and reply templates ([a01cb3a](https://github.com/czj/triamail/commit/a01cb3ab3b7cf82a232cbf9dd8f1b42c4595fa00))
* releases installable as a DMG and with Homebrew ([47ce2eb](https://github.com/czj/triamail/commit/47ce2eb570ce1176b8cb1a5b1bd1ec063cb6cdc5))
* reminders at D+1, D+3, D+7 or on a date (C4) ([4727124](https://github.com/czj/triamail/commit/47271247b9f632f77c3f9bc45df0d7c9d478004a))
* settings in an iCloud Drive folder and secrets in the keychain ([3298ab9](https://github.com/czj/triamail/commit/3298ab9427fd9126601a4d44623123370a5908ee))
* summary of an email or a thread (C7) ([06f8142](https://github.com/czj/triamail/commit/06f8142ae40383bc12586fdc67f23c430fa75863))
* Tidy button for Downloads, Desktop and scans ([598bfd0](https://github.com/czj/triamail/commit/598bfd0f8b7092c00f4a4a972b747f8d85704e68))


### Bug Fixes

* ad hoc signed release with an increasing build number ([d4a30c3](https://github.com/czj/triamail/commit/d4a30c32ea8e3975384a2526d2f80171d4d22dc1))
* an abandoned Gmail sign-in stops after 5 minutes ([dafba36](https://github.com/czj/triamail/commit/dafba36d6f03fb6a2ac20eda882ac1293fb5d767))
* invoice archiving without duplicates or garbled text ([f1cbb02](https://github.com/czj/triamail/commit/f1cbb024aa10cc05266f71a0beed6d31948e0b01))
* never overwrite unreadable settings ([65d530c](https://github.com/czj/triamail/commit/65d530c8e5496a5a47c1162f4a661b4ca1788bab))
* publish the release only once the app is attached ([9c62a1d](https://github.com/czj/triamail/commit/9c62a1defd27e3ed899717ed0fdef06eb4e2a221))
* resume an interrupted translation ([1c59f07](https://github.com/czj/triamail/commit/1c59f072501fc2272a5274fc4343f8c5e1af5135))
* the AI reply stays attached to its email ([ca8f803](https://github.com/czj/triamail/commit/ca8f80312ed2ba78402ab51dd25c8f2d6b380f36))
* Tidy files a dated file by the date in its name ([94390c8](https://github.com/czj/triamail/commit/94390c8c6e4e1a0263442fc462b8d7ea215af785))


### Performance

* accounts loaded in parallel, Gmail requests limited to 8 at a time ([5575b06](https://github.com/czj/triamail/commit/5575b061cbad6bca9fa5eecbe843de9a9cf839e2))


### Documentation

* /code-review and /simplify before each PR ([c9fca8b](https://github.com/czj/triamail/commit/c9fca8b859a996a11ce63648df21285353aa03a4))
* mises à jour automatiques avec Sparkle ([8cca90d](https://github.com/czj/triamail/commit/8cca90df729a071da048ae52b7d2a9dab373acb6))
* README updated with getting started ([86f4161](https://github.com/czj/triamail/commit/86f416119e7f334d8d3f7ec2cb69974531bfd0c8))

## 0.1.0 (2026-11-08)


### Nouveautés

* archiver une facture au clic (C5) ([#26](https://github.com/czj/triamail/issues/26)) ([fce1920](https://github.com/czj/triamail/commit/fce19207e907afe767cf8cb892c4172f2b56e4b8))
* bouton Ranger pour Téléchargements, Bureau et scans ([#27](https://github.com/czj/triamail/issues/27)) ([598bfd0](https://github.com/czj/triamail/commit/598bfd0f8b7092c00f4a4a972b747f8d85704e68))
* connexion des comptes Gmail (OAuth, PKCE, trousseau) ([#21](https://github.com/czj/triamail/issues/21)) ([9e82ff0](https://github.com/czj/triamail/commit/9e82ff07d976fd0dfd91ec72753377fd2186116c)), closes [#7](https://github.com/czj/triamail/issues/7)
* coque de l'app et moteur des règles d'archivage ([#4](https://github.com/czj/triamail/issues/4)) ([30ad13c](https://github.com/czj/triamail/commit/30ad13cb145e9ac52ec136a7ab2423661c8c4a7a))
* écran des dossiers et des règles d'archivage ([#20](https://github.com/czj/triamail/issues/20)) ([002564b](https://github.com/czj/triamail/commit/002564b0165565b3b926928d8fbdea2389f9e9e6)), closes [#6](https://github.com/czj/triamail/issues/6)
* lancer Claude Code sur le dépôt de la notification (C2) ([#31](https://github.com/czj/triamail/issues/31)) ([0a809a3](https://github.com/czj/triamail/commit/0a809a39867861c7268d121a9ed675065c8599bf))
* liste « À traiter » alimentée par Gmail ([#22](https://github.com/czj/triamail/issues/22)) ([dd4fb54](https://github.com/czj/triamail/commit/dd4fb54a43b0bd5c8878b18b7ad59e835910f7cf))
* mises à jour automatiques avec Sparkle ([#32](https://github.com/czj/triamail/issues/32)) ([0b54a4e](https://github.com/czj/triamail/commit/0b54a4e778b40a0ccd7bfbbd911bc541c42699b3)), closes [#18](https://github.com/czj/triamail/issues/18)
* page de la notification dans le panneau de droite (C1) ([#23](https://github.com/czj/triamail/issues/23)) ([6ea1273](https://github.com/czj/triamail/commit/6ea127343cd5895e597d42d5e7b27bb36e7b7fe9)), closes [#9](https://github.com/czj/triamail/issues/9)
* profil et modèles de réponse ([#28](https://github.com/czj/triamail/issues/28)) ([a01cb3a](https://github.com/czj/triamail/commit/a01cb3ab3b7cf82a232cbf9dd8f1b42c4595fa00)), closes [#14](https://github.com/czj/triamail/issues/14)
* rappels J+1, J+3, J+7 ou à une date (C4) ([#25](https://github.com/czj/triamail/issues/25)) ([4727124](https://github.com/czj/triamail/commit/47271247b9f632f77c3f9bc45df0d7c9d478004a)), closes [#11](https://github.com/czj/triamail/issues/11)
* réglages dans un dossier iCloud Drive et secrets dans le trousseau ([#19](https://github.com/czj/triamail/issues/19)) ([3298ab9](https://github.com/czj/triamail/commit/3298ab9427fd9126601a4d44623123370a5908ee)), closes [#5](https://github.com/czj/triamail/issues/5)
* releases installables en DMG et avec Homebrew ([#46](https://github.com/czj/triamail/issues/46)) ([47ce2eb](https://github.com/czj/triamail/commit/47ce2eb570ce1176b8cb1a5b1bd1ec063cb6cdc5))
* réponses IA rédigées en fond et déposées en brouillon (C3) ([#29](https://github.com/czj/triamail/issues/29)) ([ab8551a](https://github.com/czj/triamail/commit/ab8551a29a2a0d5eab64892d28e624c0d067070b)), closes [#15](https://github.com/czj/triamail/issues/15)
* résumé d'un mail ou d'un fil (C7) ([#30](https://github.com/czj/triamail/issues/30)) ([06f8142](https://github.com/czj/triamail/commit/06f8142ae40383bc12586fdc67f23c430fa75863)), closes [#16](https://github.com/czj/triamail/issues/16)
* traduction automatique et locale des mails étrangers (C6) ([#24](https://github.com/czj/triamail/issues/24)) ([6c0a1be](https://github.com/czj/triamail/commit/6c0a1be1c5e3557b41a632fcb8b414696515aa65))


### Corrections

* archivage de facture sans doublon ni texte abîmé ([#37](https://github.com/czj/triamail/issues/37)) ([f1cbb02](https://github.com/czj/triamail/commit/f1cbb024aa10cc05266f71a0beed6d31948e0b01))
* la connexion Gmail abandonnée s'arrête au bout de 5 minutes ([#39](https://github.com/czj/triamail/issues/39)) ([dafba36](https://github.com/czj/triamail/commit/dafba36d6f03fb6a2ac20eda882ac1293fb5d767))
* la réponse IA reste attachée à son mail ([#34](https://github.com/czj/triamail/issues/34)) ([ca8f803](https://github.com/czj/triamail/commit/ca8f80312ed2ba78402ab51dd25c8f2d6b380f36))
* ne jamais écraser des réglages illisibles ([#35](https://github.com/czj/triamail/issues/35)) ([65d530c](https://github.com/czj/triamail/commit/65d530c8e5496a5a47c1162f4a661b4ca1788bab))
* Ranger classe un fichier daté selon la date de son nom ([#40](https://github.com/czj/triamail/issues/40)) ([94390c8](https://github.com/czj/triamail/commit/94390c8c6e4e1a0263442fc462b8d7ea215af785))
* release signée ad hoc avec un numéro de build croissant ([#36](https://github.com/czj/triamail/issues/36)) ([d4a30c3](https://github.com/czj/triamail/commit/d4a30c32ea8e3975384a2526d2f80171d4d22dc1))
* reprendre une traduction interrompue ([#38](https://github.com/czj/triamail/issues/38)) ([1c59f07](https://github.com/czj/triamail/commit/1c59f072501fc2272a5274fc4343f8c5e1af5135))


### Performances

* comptes chargés en parallèle, requêtes Gmail limitées à 8 à la fois ([#45](https://github.com/czj/triamail/issues/45)) ([5575b06](https://github.com/czj/triamail/commit/5575b061cbad6bca9fa5eecbe843de9a9cf839e2))


### Documentation

* /code-review et /simplify avant chaque PR ([#33](https://github.com/czj/triamail/issues/33)) ([c9fca8b](https://github.com/czj/triamail/commit/c9fca8b859a996a11ce63648df21285353aa03a4))
* mises à jour automatiques avec Sparkle ([8cca90d](https://github.com/czj/triamail/commit/8cca90df729a071da048ae52b7d2a9dab373acb6))
* README à jour avec la mise en route ([#41](https://github.com/czj/triamail/issues/41)) ([86f4161](https://github.com/czj/triamail/commit/86f416119e7f334d8d3f7ec2cb69974531bfd0c8))

## Changelog

Ce fichier est tenu à jour automatiquement par release-please à partir des messages de commit.

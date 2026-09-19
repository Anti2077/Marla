<div align="center">
  <img src="Resources/Brand/PaperLantern/logo-512.png" width="112" alt="Symbole Paper Lantern de Marla">
  <h1>Marla</h1>
  <p><strong>La traduction qui reste à côté de ce que vous lisez.</strong></p>
  <p>Une couche de traduction native pour macOS, qui apparaît à votre demande, reste près du contenu source et sait se faire discrète.</p>
  <p>Éclairez la traduction à côté du texte source, lisez-la, puis reprenez votre travail sans changer de contexte.</p>

  <p>
    <a href="README.md">简体中文</a> ·
    <a href="README.en.md">English</a> ·
    <a href="README.ja.md">日本語</a> ·
    <a href="README.fr.md">Français</a> ·
    <a href="README.es.md">Español</a> ·
    <a href="README.de.md">Deutsch</a> ·
    <a href="README.ko.md">한국어</a>
  </p>

  <p>
    <img src="https://img.shields.io/badge/status-incubation-C86652?style=flat-square" alt="État : incubation">
    <img src="https://img.shields.io/badge/platform-macOS%2014%2B-393554?style=flat-square&amp;logo=apple&amp;logoColor=white" alt="Plateforme : macOS 14 ou version ultérieure">
    <img src="https://img.shields.io/badge/Swift-6.2-C86652?style=flat-square&amp;logo=swift&amp;logoColor=white" alt="Swift 6.2">
    <img src="https://img.shields.io/badge/Rust-1.85-E6B86A?style=flat-square&amp;logo=rust&amp;logoColor=393554" alt="Rust 1.85">
  </p>

  <p>
    <a href="website/">Page de présentation de Marla</a> ·
    <a href="https://github.com/Anti2077/Marla/releases/latest">Télécharger (GitHub Releases)</a> ·
    <a href="https://github.com/Anti2077/Marla">GitHub</a>
  </p>

  <p>
    <a href="#pourquoi-marla">Pourquoi Marla</a> ·
    <a href="#trois-modes-dentrée">Parcours</a> ·
    <a href="#une-confidentialité-sans-formule-vague">Confidentialité</a> ·
    <a href="#développement">Développement</a> ·
    <a href="docs/README.md">Documentation</a>
  </p>
</div>

<p align="center">
  <strong><a href="website/public/media/desktop/marla-hero-in-place--desktop-5x4.mp4">Voir le véritable parcours Marla (MP4)</a></strong>
</p>

<p align="center"><sub>Capture réelle de l'application native macOS. GitHub ouvre le MP4 dans son lecteur multimédia.</sub></p>

## Pour commencer

La page de présentation de Marla se trouve dans [`website/`](website/). Pour télécharger l'application, rendez-vous sur [GitHub Releases](https://github.com/Anti2077/Marla/releases/latest) ; le code source et les journaux de développement sont disponibles dans le [dépôt GitHub](https://github.com/Anti2077/Marla). Le dépôt est encore en préparation avant publication, il est donc possible que la page Releases ne contienne pas encore de fichier à télécharger.

## Pourquoi Marla

La plupart des outils de traduction deviennent une destination supplémentaire. Marla garde l'application en cours d'utilisation comme surface principale : invoquez la traduction avec un raccourci, lisez le résultat à proximité, fermez-le et reprenez votre travail au même endroit.

- **Reste sur place.** Les résultats d'une sélection ou d'une capture d'écran apparaissent dans une fiche native à proximité, et non dans une fenêtre de traduction principale.
- **Montre immédiatement votre intention.** La surface stable du résultat apparaît avant la réponse réseau et grandit avec le contenu reçu en streaming.
- **Préserve la structure.** Quick Input et les sélections enrichies prises en charge conservent le Markdown sémantique pendant la traduction et le rendu natif.
- **Permet de remplacer les fournisseurs.** Les profils OpenAI compatibles et nommés font du point de terminaison et du modèle de traduction des choix explicites de l'utilisateur.

## Trois modes d'entrée

| Entrée | Raccourci par défaut | Fonctionnement |
| --- | --- | --- |
| **Texte sélectionné** | `⌃⇧D` | Marla récupère la sélection actuelle de manière protégée et affiche le résultat en streaming à côté du contenu source. |
| **Zone de l'écran** | `⌃⇧S` | Une image figée couvrant plusieurs écrans permet de sélectionner une zone, d'utiliser Vision OCR localement ou une option GLM-OCR choisie explicitement. |
| **Quick Input** | `⌃⇧Space` | Un éditeur compact traduit le contenu saisi ou collé, y compris les structures Markdown prises en charge. |

Les raccourcis sont configurables. Une fois terminés, les résultats prennent en charge la comparaison, la copie, une nouvelle tentative, la lecture vocale du système, l'épinglage, le changement de langue et le changement de fournisseur, sans transformer Marla en espace de travail documentaire.

## Natif là où cela compte

```text
Déclenchement explicite
  → acquisition et présentation avec SwiftUI / AppKit
  → ABI C versionnée dans le même processus
  → cœur Rust intégré pour les fournisseurs, le streaming, la normalisation et l'annulation
  → surface de résultat native à proximité
```

Marla est une application macOS écrite en Swift 6. SwiftUI gère les surfaces durables, tandis qu'AppKit prend en charge la barre des menus, les panneaux, le focus et les interactions au niveau de l'écran. Le cœur Rust 2024 est intégré sous forme de bibliothèque statique : il n'existe ni serveur localhost ni service séparé fonctionnant en permanence.

## Une confidentialité sans formule vague

| Parcours | Limite actuelle |
| --- | --- |
| **Traduction d'une sélection** | Seule une transaction Copy protégée et déclenchée explicitement peut fournir du contenu. Accessibility sert aux autorisations et au positionnement, jamais de source de texte cachée. |
| **OCR de capture avec Vision** | La zone de capture sélectionnée reste locale pour l'OCR. La traduction du texte peut toutefois utiliser le fournisseur cloud configuré. |
| **GLM-OCR** | Les pixels de la capture sont téléversés uniquement lorsque l'utilisateur sélectionne explicitement GLM-OCR après avoir pris connaissance de l'information affichée dans Settings. |
| **Stockage** | Les captures d'écran et les traductions récentes restent limitées à la session. L'historique de traduction persistant et la collecte du texte contextuel des fenêtres ne sont pas implémentés. |

Marla ne prétend pas fonctionner entièrement hors ligne. Les limites précises concernant le fournisseur, l'OCR et les données sont volontairement visibles au lieu d'être regroupées sous un slogan unique sur la confidentialité.

## Langues prises en charge

L'ensemble actuel des langues du produit Marla comprend sept options :

| Langue | Code |
| --- | --- |
| 简体中文 / Chinois simplifié | `zh-Hans` |
| English / Anglais | `en` |
| 日本語 / Japonais | `ja` |
| Français | `fr` |
| Español / Espagnol | `es` |
| Deutsch / Allemand | `de` |
| 한국어 / Coréen | `ko` |

Le chinois traditionnel est normalisé vers l'option de chinois simplifié et ne constitue pas une préférence distincte. La documentation des fournisseurs peut mentionner davantage de langues ; Marla ne les déclare pas prises en charge par le produit tant que la détection, le routage, l'interface et la correspondance avec les fournisseurs n'ont pas été vérifiés ensemble.

## État du projet

Marla reste en phase **Incubation / Unreleased** pendant la préparation de ses points d'accès publics. L'application native et ses parcours principaux sont implémentés, mais aucune Release publique, version produit attribuée, archive notariée, fonction de mise à jour ou licence publique sélectionnée n'a encore été déclarée.

- [État de développement vérifié](docs/development/STATUS.md)
- [Définition du produit](docs/product/PRODUCT.md)
- [Architecture](docs/architecture/ARCHITECTURE.md)
- [Identité Paper Lantern](docs/product/BRAND.md)
- [Page de présentation de Marla](website/)
- [Notes d'implémentation du site](website/README.md)

## Développement

### Prérequis

- macOS 14 ou version ultérieure sur Apple Silicon
- Xcode 26.5 ou une installation complète et compatible de Xcode
- Swift 6.2 ou version ultérieure
- Rust 1.85 ou version ultérieure

Exécutez la vérification complète du dépôt :

```sh
./scripts/check.sh
```

Ce script formate, compile et teste le cœur Rust et la couche Swift, compile l'application native Debug avec la bibliothèque de débogage Cargo, valide la structure du projet et vérifie le diff. Il sélectionne l'installation complète de Xcode uniquement pour ses propres commandes et ne modifie pas le réglage `xcode-select` de la machine.

Compilez l'application de développement Release, signée de manière stable et écrite à un emplacement fixe :

```sh
./scripts/build-test-app.sh
```

L'artefact vérifié est écrit dans `artifacts/Marla_dev.app` avec la Marketing Version de développement `0.0.0`. Cette valeur numérique est une métadonnée du paquet et non une version publique du produit.

<details>
<summary><strong>Première compilation locale signée</strong></summary>

Le script d'empaquetage exige une identité locale stable de signature de code et ne bascule jamais silencieusement vers une signature ad hoc. Indiquez un nom d'identité ou l'empreinte d'un certificat affiché par `security find-identity -v -p codesigning` :

```sh
MARLA_CODE_SIGN_IDENTITY="Your Local Code Signing Identity" \
./scripts/build-test-app.sh
```

Les compilations ultérieures sans argument récupèrent l'empreinte du certificat depuis l'application fixe existante et vérifient que son designated requirement reste stable avant de la remplacer. Cela sert uniquement aux tests locaux et ne fournit ni distribution Developer ID, ni notarisation, ni approbation TCC automatique.

</details>

### Organisation du dépôt

| Chemin | Rôle |
| --- | --- |
| `Sources/MarlaApp/` | Application SwiftUI/AppKit, acquisition, réglages, sessions et présentation |
| `Sources/MarlaCore/` | Modèles de pont destinés à Swift et contrats des fournisseurs |
| `Sources/MarlaRustFFI/` | Pont C versionné entre Swift et Rust |
| `rust/marla-core/` | Cœur intégré pour les fournisseurs, le streaming, la normalisation OCR et l'annulation |
| `website/` | Prototype indépendant de page produit en React/Vite |
| `docs/` | Vérité produit, architecture, Tasks, état et preuves de vérification |
| `scripts/` | Vérifications du dépôt, empaquetage et validation des artefacts |

Commencez par le [plan de la documentation](docs/README.md), puis consultez l'[état actuel](docs/development/STATUS.md) et son Active Task avant toute modification. Le dépôt sépare délibérément les idées produit, le Backlog confirmé, l'implémentation active et les preuves vérifiées.

---

<p align="center"><sub>Paper Lantern : une petite lumière à côté du lecteur.</sub></p>

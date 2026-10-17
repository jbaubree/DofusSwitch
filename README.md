# DofusSwitch

Petite app macOS dans la barre de menus pour switcher entre tes fenêtres Dofus Unity avec un raccourci clavier global. Zéro bloat : pas de gestion de comptes, pas de tiling, pas de télémétrie.

## Fonctionnalités

- Détection automatique des clients Dofus Unity qui tournent
- Deux raccourcis globaux configurables : fenêtre suivante / précédente (défauts : `⌃⌥→` / `⌃⌥←`)
- Toggle on/off des raccourcis depuis les settings
- Liste réordonnable dans le popover (drag-and-drop)
- Démarrage au login
- Icône Dofus récupérée dynamiquement depuis le bundle installé par Zaap
- Pas de réseau, pas de télémétrie, pas d'enregistrement d'écran requis

## Prérequis

- macOS 13 (Ventura) ou plus
- Xcode 15+ et `xcodegen` pour builder (`brew install xcodegen`)
- Permission Accessibilité (demandée au premier lancement)

## Build & lancement

```bash
xcodegen generate
xcodebuild -scheme DofusSwitch -configuration Debug build
open ~/Library/Developer/Xcode/DerivedData/DofusSwitch-*/Build/Products/Debug/DofusSwitch.app
```

Au premier lancement macOS peut bloquer l'app (signée ad-hoc) : clic droit sur `DofusSwitch.app` → **Ouvrir** → **Ouvrir** dans la confirmation.

## Permission Accessibilité

Au premier lancement un écran "Autorisation requise" apparaît dans le popover. Clique **Ouvrir Réglages Système** → active le toggle **DofusSwitch** dans *Confidentialité et sécurité* → *Accessibilité* → reviens sur le popover et clique **Revérifier**.

Si tu rebuild l'app et que l'autorisation ne tient plus (classique avec les signatures ad-hoc qui changent à chaque build) :

```bash
pkill -f DofusSwitch
tccutil reset Accessibility com.jbaubree.DofusSwitch
open ~/Library/Developer/Xcode/DerivedData/DofusSwitch-*/Build/Products/Debug/DofusSwitch.app
```

## Utilisation rapide

1. Lance au moins 2 clients Dofus Unity.
2. Clique sur l'icône Dofus dans la barre de menus → tes personnages apparaissent (format `Perso - Classe`).
3. `⌃⌥→` passe au suivant, `⌃⌥←` au précédent (modifiables dans Settings).
4. Glisse une ligne pour réordonner — l'ordre est persisté entre les lancements.
5. Ferme un client → il disparaît de la liste en ~2 secondes.

### Personnaliser les raccourcis

Clique sur l'engrenage → clique sur le champ d'un raccourci → appuie sur la combinaison voulue (ou une touche seule — Échap annule). Un switch en haut permet de désactiver complètement les raccourcis sans les désassigner.

**Attention aux raccourcis sans modifier :** une touche nue (ex: flèche droite seule) est globale et sera interceptée dans toutes les apps, pas juste Dofus.

## Limitations connues

- **Dofus Unity uniquement.** Pas de support Dofus Rétro ni Experimental.
- **Persistance de l'ordre.** La clé est basée sur le titre nettoyé de la fenêtre (`Perso - Classe`). Si Dofus change le format des titres dans une mise à jour, l'ordre peut être réinitialisé.
- **Signature ad-hoc.** Pas de Developer ID. Gatekeeper demande une confirmation au premier lancement et la permission Accessibilité est à redonner après chaque rebuild.
- **Fenêtre launcher ignorée.** Celle intitulée `Dofus x.y.z - Release` est exclue de la liste (ce n'est pas un personnage).

## Non-objectifs

- **Pas de broadcast d'inputs.** Interdit par Ankama. L'app ne fait que focaliser des fenêtres.
- **Pas d'automatisation du gameplay.** Zéro simulation de clic ou de touche à destination du jeu.
- **Pas de lecture mémoire.** L'app ne touche jamais aux process Dofus autrement que via l'API publique Accessibility pour lister et focaliser leurs fenêtres.

## Architecture

Deux targets :

- **DofusSwitchCore** (framework) — logique métier testable : `TrackedWindow`, `HotkeyBinding`, `Preferences`, `WindowStore` (fusion détecté × ordre persisté avec entrées fantômes), `CycleController`.
- **DofusSwitch** (application) — glue AppKit/SwiftUI :
  - `WindowDetector` : AX API + `NSWorkspace` + `AXObserver` + poll de secours à 2s
  - `HotkeyManager` : Carbon `RegisterEventHotKey`
  - `FocusService` : `kAXMainAttribute` + `kAXRaiseAction` + `NSRunningApplication.activate`
  - `LaunchAtLoginService` : `SMAppService.mainApp`
  - UI SwiftUI dans un `NSPopover` attaché à un `NSStatusItem`

30 tests XCTest sur la Core. Les services système ne sont pas testés automatiquement (nécessitent Dofus qui tourne et un accès au focus système).

## Licence

MIT.

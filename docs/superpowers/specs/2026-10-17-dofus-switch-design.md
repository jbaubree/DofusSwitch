# DofusSwitch — Design Spec

**Date :** 2026-10-17
**Status :** Draft (en cours de validation utilisateur)

## 1. Objectif

Une app macOS minimaliste pour switcher entre plusieurs fenêtres Dofus Unity via raccourci clavier global. Pensée pour les joueurs multi-comptes qui veulent uniquement la gestion des fenêtres — pas de gestion de personnages, pas de stockage de credentials, pas de teams, pas de tiling.

**Non-objectifs :**
- Pas de broadcast d'input (interdit par Ankama)
- Pas de lecture mémoire du jeu
- Pas de télémétrie, pas de réseau
- Pas de miniatures de fenêtres (nécessiterait Screen Recording)
- Pas de support Dofus Rétro / Experimental (Unity uniquement)

## 2. Fonctionnalités

| ID | Feature |
|---|---|
| F1 | Détection automatique des fenêtres Dofus Unity qui tournent |
| F2 | Hotkey global **next** : focus la fenêtre suivante dans l'ordre |
| F3 | Hotkey global **previous** : focus la fenêtre précédente |
| F4 | Icône menu bar avec popover listant les fenêtres détectées |
| F5 | Réordonnancement de la liste par drag-and-drop |
| F6 | Hotkeys configurables depuis l'écran settings du popover |
| F7 | Launch at login (optionnel) |
| F8 | Persistance de l'ordre et des hotkeys entre sessions |

Les hotkeys par défaut : `⌃⌥→` (next), `⌃⌥←` (previous).

## 3. Architecture

### Composants

| Composant | Responsabilité | Dépendances |
|---|---|---|
| `WindowDetector` | Observer les apps Dofus Unity et énumérer leurs fenêtres via Accessibility API | NSWorkspace, AX API |
| `WindowStore` | `ObservableObject` — source de vérité unique : liste détectée × ordre utilisateur persisté | — |
| `HotkeyManager` | Enregistrer/désenregistrer les 2 hotkeys globaux (Carbon `RegisterEventHotKey`) | — |
| `CycleController` | Index courant, logique next/prev, déclenche le focus | WindowStore |
| `FocusService` | Donner le focus à une fenêtre (activate + raise + main) | AX API |
| `MenuBarController` | Cycle de vie `NSStatusItem` + `NSPopover` | — |
| `PopoverView` (SwiftUI) | Liste réordonnable + settings | WindowStore |
| `Preferences` | Codable, persisté dans UserDefaults | — |

### Data flow

```
NSWorkspace / AXObserver ──▶ WindowDetector ──▶ WindowStore ──▶ PopoverView
                                                     │                │
                                                     ▼                │ reorder
                                              CycleController         │
                                                     │  ◀─────────────┘
                                     next/prev hotkey│
HotkeyManager ──────────────────────────────────────┘
                                                     ▼
                                              FocusService ──▶ AX API
```

Toute communication passe par `WindowStore`. Aucun composant ne connaît un autre directement.

## 4. Détection des fenêtres

**Identification de Dofus Unity :**
- Filtrer `NSWorkspace.shared.runningApplications` par `bundleIdentifier` ≈ `com.ankama.dofus` *(à confirmer au premier run)*.

**Énumération des fenêtres d'une instance :**
- `AXUIElementCreateApplication(pid)` → `AXUIElementCopyAttributeValue(kAXWindowsAttribute)`.
- Filtre : titre non vide, pas une sous-fenêtre système.

**Synchronisation :**
- `NSWorkspace.notificationCenter` : `didLaunchApplicationNotification` / `didTerminateApplicationNotification` → re-scan.
- `AXObserver` par app vivante : `kAXWindowCreatedNotification`, `kAXUIElementDestroyedNotification`, `kAXTitleChangedNotification`.
- Poll de secours toutes les 2s (supprimable plus tard si les notifs couvrent tout dans la pratique).

**Identité stable d'une fenêtre :**
- Runtime : `AXUIElement` comparé via `CFEqual`.
- Persistance : `windowTitle` normalisé (contient le pseudo du perso en principe — *à confirmer au premier run*).

### Points à vérifier au premier run

1. Bundle identifier exact de Dofus Unity sur macOS.
2. Format du titre de fenêtre et stabilité du pseudo dedans.

Si l'un de ces points casse l'identité stable (titre vide ou pseudo absent), fallback : identité basée sur ordre de lancement, persistance désactivée pour les process relancés.

## 5. Hotkeys globaux

**API :** Carbon `RegisterEventHotKey` / `UnregisterEventHotKey` + `InstallEventHandler` partagé qui dispatche sur le `hotKeyID`. Pas de dépendance externe.

**Interface :**
```swift
enum HotkeyID: UInt32 { case next = 1, prev = 2 }

final class HotkeyManager {
  var onHotkey: ((HotkeyID) -> Void)?
  func register(_ id: HotkeyID, keyCode: UInt32, modifiers: UInt32) throws
  func unregister(_ id: HotkeyID)
}
```

**Capture dans l'UI :** vue AppKit `HotkeyRecorderField` qui au clic passe en mode "capture", intercepte le prochain `NSEvent.keyDown` global pour cette fenêtre, extrait `(keyCode, modifierFlags)`.

**Conversion :** NSEvent modifiers → Carbon modifiers via petit mapping (`cmdKey`, `optionKey`, `controlKey`, `shiftKey`).

## 6. Focus d'une fenêtre

Séquence atomique pour éviter le flash de la mauvaise fenêtre :

```swift
func focus(_ w: TrackedWindow) {
  // 1. Remonte la fenêtre AVANT l'activation
  AXUIElementSetAttributeValue(w.axElement, kAXMainAttribute as CFString, kCFBooleanTrue)
  AXUIElementPerformAction(w.axElement, kAXRaiseAction as CFString)
  // 2. Active l'app
  NSRunningApplication(processIdentifier: w.pid)?.activate(options: .activateIgnoringOtherApps)
}
```

Si l'`AXUIElement` est devenu invalide (fenêtre fermée entre temps), le code trap l'erreur AX et déclenche un re-scan.

## 7. UI du popover

**Vue SwiftUI dans un `NavigationStack`, hébergée par `NSHostingController` dans un `NSPopover` détaché.**

### Écran principal — liste

```
┌────────────────────────────┐
│  Dofus windows          ⚙  │
├────────────────────────────┤
│  ⚔  Perso1    (en cours)  │
│  ⚔  Perso2                 │
│  ⚔  Perso3                 │
├────────────────────────────┤
│  Aucune fenêtre détectée  │  (si vide)
├────────────────────────────┤
│                     Quit ⏻ │
└────────────────────────────┘
```

- `List` SwiftUI + `.onMove` → drag-and-drop natif.
- Chaque ligne : badge "D" (ou icône de l'app Dofus récupérée via `NSRunningApplication.icon`) + titre + indicateur si c'est la fenêtre courante selon `CycleController`.

### Écran settings

```
┌────────────────────────────┐
│  ← Settings                │
├────────────────────────────┤
│  Next window     ⌃⌥→      │
│  Previous window ⌃⌥←      │
├────────────────────────────┤
│  Launch at login       [●] │
├────────────────────────────┤
│  Reset to defaults         │
└────────────────────────────┘
```

- 2 `HotkeyRecorderField` (next/prev)
- Toggle "Launch at login" (`SMAppService.mainApp`)
- Bouton reset

**Taille popover :** 280×360, non-resizable.

## 8. Persistance

Un seul blob JSON dans `UserDefaults`, clé `com.jbaubree.DofusSwitch.preferences`.

```swift
struct Preferences: Codable {
  var nextHotkey: HotkeyBinding
  var prevHotkey: HotkeyBinding
  var windowOrder: [String]   // titres normalisés, ordre persisté
  var launchAtLogin: Bool
}

struct HotkeyBinding: Codable, Equatable {
  var keyCode: UInt32
  var modifiers: UInt32
}
```

Au scan, `WindowStore` fusionne `detectedWindows` avec `windowOrder` :
1. Fenêtres dont le titre est connu : positionnées selon `windowOrder`
2. Fenêtres nouvelles : append en fin
3. Titres de `windowOrder` sans fenêtre correspondante : conservés dans l'ordre (positions "fantômes" ignorées à l'affichage mais préservées pour la prochaine fois)

Persistance déclenchée par :
- Drag-and-drop (`.onMove`)
- Changement de hotkey
- Toggle launch at login

## 9. Permissions & packaging

**Permissions :**
- **Accessibility (obligatoire).** Au premier launch : `AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true])`. Si refusé, le popover affiche une vue d'onboarding avec bouton "Ouvrir Réglages Système" (`x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`).
- Pas de Screen Recording.
- Pas d'entitlement réseau.

**Packaging :**
- Target : **macOS 13 (Ventura)+**
- `LSUIElement = true` → pas de Dock icon
- Hardened runtime ON, sandbox OFF (sandbox incompatible avec AX cross-process)
- Signing : ad-hoc en v1, DMG distribué avec notice "clic droit → Ouvrir au premier lancement"
- Pas d'auto-update en v1

## 10. Testing

**Unitaires (XCTest) :**
- `WindowStoreTests` — merge detected ↔ ordered, fenêtres fantômes, ordre préservé
- `CycleControllerTests` — next/prev, wrap-around, liste vide, 1 seul élément
- `PreferencesTests` — encode/decode, migration future
- `HotkeyBindingTests` — conversion NSEvent ↔ Carbon modifiers

**Non testés automatiquement** (nécessitent Dofus + focus système) :
- `WindowDetector`, `HotkeyManager`, `FocusService`

**Smoke test manuel** documenté dans `README.md` :
1. Lancer 2 instances Dofus
2. Vérifier qu'elles apparaissent dans le popover
3. `⌃⌥→` → focus doit changer de fenêtre
4. Réordonner par drag-and-drop
5. Re-tester le cycle respecte le nouvel ordre
6. Fermer une instance → disparaît du popover
7. Quit app → re-lancer → ordre et hotkeys restaurés

## 11. Structure du projet

```
DofusSwitch/
├── DofusSwitch.xcodeproj
├── DofusSwitch/
│   ├── App/
│   │   ├── DofusSwitchApp.swift      (NSApplicationDelegate)
│   │   └── Info.plist                 (LSUIElement, usage descriptions)
│   ├── Core/
│   │   ├── WindowDetector.swift
│   │   ├── WindowStore.swift
│   │   ├── TrackedWindow.swift
│   │   ├── HotkeyManager.swift
│   │   ├── CycleController.swift
│   │   ├── FocusService.swift
│   │   └── Preferences.swift
│   ├── MenuBar/
│   │   ├── MenuBarController.swift
│   │   └── HotkeyRecorderField.swift
│   └── UI/
│       ├── PopoverView.swift
│       ├── WindowListView.swift
│       ├── SettingsView.swift
│       └── OnboardingView.swift
├── DofusSwitchTests/
│   ├── WindowStoreTests.swift
│   ├── CycleControllerTests.swift
│   ├── PreferencesTests.swift
│   └── HotkeyBindingTests.swift
├── docs/
│   └── superpowers/
│       └── specs/
│           └── 2026-10-17-dofus-switch-design.md   (ce document)
├── README.md
└── .gitignore
```

## 12. Risques & questions ouvertes

| Risque | Mitigation |
|---|---|
| Bundle ID Dofus inconnu | Vérification manuelle au premier run — fallback possible par nom de process |
| Titre de fenêtre instable ou vide | Fallback identité par ordre de lancement, pas de persistance |
| Dofus Unity peut créer des fenêtres transientes (dialog login, etc.) | Filtre par taille minimale ou par rôle AX (`kAXWindowRole`) |
| Ad-hoc signing → warning Gatekeeper au premier lancement | Documenté dans README |

## 13. Scope v1 vs plus tard

**v1 (ce spec) :**
F1–F8 ci-dessus. Rien d'autre.

**Explicitement reporté (potentiel v2) :**
- Hotkey "cycle one direction only" (si le user change d'avis)
- Icône personnalisable
- Thèmes
- Support Dofus Rétro
- Developer ID signing + notarization
- Auto-update (Sparkle)

# Auto-désactivation des raccourcis selon le nombre de sessions Dofus

**Date** : 2026-10-19
**Statut** : spec validé

## Contexte

Les raccourcis globaux (`⌃⌥→` / `⌃⌥←`) permettent de cycler entre les fenêtres Dofus. Ils sont enregistrés auprès de Carbon dès que l'app démarre, dès lors que le toggle "Raccourcis globaux" est ON dans les settings.

Problème : quand une seule session (ou zéro) tourne, il n'y a rien à cycler mais les raccourcis restent globaux et peuvent entrer en conflit avec d'autres apps inutilement.

## Objectif

Désactiver automatiquement l'enregistrement Carbon des raccourcis quand `< 2` sessions Dofus sont détectées, et le réactiver automatiquement quand on repasse à `≥ 2`.

## Règle d'activation

Les raccourcis sont enregistrés auprès de Carbon si et seulement si :

```
preferredEnabled == true  &&  sessionCount >= 2
```

Où :
- `preferredEnabled` = `Preferences.hotkeysEnabled` (toggle utilisateur dans Settings)
- `sessionCount` = `WindowStore.visibleWindows.count`

Table de vérité :

| toggle `hotkeysEnabled` | `sessionCount` | Raccourcis enregistrés ? |
|---|---|---|
| OFF | 0 | non |
| OFF | 1 | non |
| OFF | ≥ 2 | non |
| ON | 0 | non (auto) |
| ON | 1 | non (auto) |
| ON | ≥ 2 | oui |

Le toggle utilisateur reste maître : OFF désactive dans tous les cas. Le seuil `2` est en dur (constante nommée).

## Architecture

### Core — `Sources/DofusSwitchCore/HotkeyActivation.swift` (nouveau)

Fonction pure, testable sans aucune dépendance système :

```swift
public let hotkeyMinimumSessions = 2

public func shouldEnableHotkeys(preferredEnabled: Bool, sessionCount: Int) -> Bool {
    preferredEnabled && sessionCount >= hotkeyMinimumSessions
}
```

### App — `Sources/DofusSwitch/AppDelegate.swift` (modifié)

`applyHotkeyState()` consulte désormais la fonction pure au lieu de regarder `prefs.hotkeysEnabled` seule :

```swift
private func applyHotkeyState() {
    let effective = shouldEnableHotkeys(
        preferredEnabled: prefs.hotkeysEnabled,
        sessionCount: windowStore.visibleWindows.count
    )
    if effective {
        hotkeyManager.rebind(next: prefs.nextHotkey, prev: prefs.prevHotkey)
    } else {
        hotkeyManager.unregisterAll()
    }
}
```

`applyHotkeyState()` doit être appelée aux moments suivants (déjà fait sauf le point 4) :
1. Au démarrage, après `windowStore.update(detected:)` initial.
2. Quand le toggle `hotkeysEnabled` change (`updateHotkeysEnabled`).
3. Quand `nextHotkey` / `prevHotkey` changent (déjà le cas).
4. **Nouveau** : à chaque update du détecteur, après `windowStore.update(detected:)`, pour qu'un ajout/retrait de session déclenche l'enregistrement/désenregistrement Carbon.

Le callback `detector.onUpdate` devient :

```swift
detector.onUpdate = { [weak self] windows in
    guard let self else { return }
    self.windowStore.update(detected: windows)
    self.menuBar?.refreshIcon()
    self.applyHotkeyState()
}
```

### UI — `Sources/DofusSwitch/UI/SettingsView.swift` (modifié)

Nouveau binding `sessionCount: Int` injecté depuis `AppDelegate` via `PopoverRootView`.

Sous les deux lignes de raccourcis, afficher un texte secondaire conditionnel :

- Visible uniquement si `hotkeysEnabled == true && sessionCount < hotkeyMinimumSessions`.
- Texte : `"Inactifs : lance au moins 2 clients Dofus."`
- Style : `.font(.caption)` + `.foregroundStyle(.secondary)`.
- Pas d'icône, pas d'alerte visuelle agressive — c'est un simple hint discret.

Les deux `HotkeyRecorderField` restent interactifs (modifier la combinaison reste possible), mais `.opacity(0.4)` dans ce cas aussi (même traitement que `hotkeysEnabled == false`).

Opacité des recorders calculée via la même fonction pure (évite la duplication de la règle) :

```swift
private var effectivelyEnabled: Bool {
    shouldEnableHotkeys(preferredEnabled: hotkeysEnabled, sessionCount: sessionCount)
}
// ...
.opacity(effectivelyEnabled ? 1 : 0.4)
```

### UI — `Sources/DofusSwitch/UI/PopoverRootView.swift` (modifié)

Ajoute le binding `sessionCount` reçu depuis AppDelegate et le transmet à `SettingsView`.

### App — binding de `sessionCount` dans `AppDelegate`

Le `WindowStore` est déjà `@ObservableObject` avec `visibleWindows` publié. Deux options :
- (a) Passer `windowStore` directement à `SettingsView` et laisser SwiftUI observer.
- (b) Exposer un closure `sessionCountProvider: () -> Int` comme pour `currentWindowKey`.

Choisir **(b)** par cohérence avec `currentWindowKey` déjà présent dans `PopoverRootView`.

## Tests

### Nouveau fichier `Tests/DofusSwitchCoreTests/HotkeyActivationTests.swift`

Cas couverts :

| Nom du test | preferredEnabled | sessionCount | Attendu |
|---|---|---|---|
| `testDisabledWhenToggleOff_zeroSessions` | false | 0 | false |
| `testDisabledWhenToggleOff_oneSession` | false | 1 | false |
| `testDisabledWhenToggleOff_manySessions` | false | 5 | false |
| `testDisabledWhenToggleOn_zeroSessions` | true | 0 | false |
| `testDisabledWhenToggleOn_oneSession` | true | 1 | false |
| `testEnabledWhenToggleOn_twoSessions` | true | 2 | true |
| `testEnabledWhenToggleOn_manySessions` | true | 10 | true |

Pas de nouveaux tests sur les services système (`HotkeyManager`, `WindowDetector`, `AppDelegate`) : la logique métier vit entièrement dans la fonction pure, et le pattern "services non testés auto" est documenté dans le README.

## Non-objectifs

- **Pas de seuil configurable.** Le `2` est en dur. Si un utilisateur veut un seuil différent, c'est une évolution future.
- **Pas de changement de l'icône de la barre de menus** quand les raccourcis sont auto-désactivés. Déjà discuté : feedback texte dans Settings uniquement.
- **Pas de notification système** quand les raccourcis s'activent/désactivent automatiquement.
- **Pas de persistance d'un état "auto-désactivé".** C'est un calcul live à partir de `visibleWindows.count` et `hotkeysEnabled`.
- **Pas de modification du schéma `Preferences`.** Aucune nouvelle clé stockée.

## Migration / compatibilité

Zéro migration. Aucun changement de persistance, aucun changement d'API publique autre que l'ajout d'un nouveau symbole exporté par la Core (`shouldEnableHotkeys`, `hotkeyMinimumSessions`).

## Fichiers touchés

Création :
- `Sources/DofusSwitchCore/HotkeyActivation.swift`
- `Tests/DofusSwitchCoreTests/HotkeyActivationTests.swift`

Modification :
- `Sources/DofusSwitch/AppDelegate.swift` (callback detector + `applyHotkeyState`)
- `Sources/DofusSwitch/UI/SettingsView.swift` (hint texte + binding `sessionCount` + opacité)
- `Sources/DofusSwitch/UI/PopoverRootView.swift` (passer le binding `sessionCount`)

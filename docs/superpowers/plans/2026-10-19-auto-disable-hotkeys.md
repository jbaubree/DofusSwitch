# Auto-désactivation des raccourcis selon le nombre de sessions — Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Désactiver automatiquement les raccourcis globaux Carbon quand `< 2` sessions Dofus sont détectées, et les réactiver automatiquement à ≥ 2.

**Architecture:** Fonction pure testable `shouldEnableHotkeys` dans `DofusSwitchCore`, appelée par `AppDelegate.applyHotkeyState()`. `AppDelegate.detector.onUpdate` déclenche désormais une réévaluation après chaque mise à jour du `WindowStore`. L'UI reçoit le compte de sessions via un closure pour afficher un hint discret dans Settings.

**Tech Stack:** Swift 5.9, SwiftUI, XCTest, xcodegen + xcodebuild. macOS 13+. Deux targets : `DofusSwitchCore` (framework, logique testable) et `DofusSwitch` (app).

**Spec de référence:** `docs/superpowers/specs/2026-10-19-auto-disable-hotkeys-design.md`

---

## File Structure

**Création :**
- `Sources/DofusSwitchCore/HotkeyActivation.swift` — fonction pure `shouldEnableHotkeys` + constante `hotkeyMinimumSessions`
- `Tests/DofusSwitchCoreTests/HotkeyActivationTests.swift` — 7 cas de la table de vérité

**Modification :**
- `Sources/DofusSwitch/AppDelegate.swift` — `applyHotkeyState` consulte la fonction pure, `detector.onUpdate` appelle `applyHotkeyState`, `PopoverRootView` reçoit un closure `sessionCount`
- `Sources/DofusSwitch/UI/PopoverRootView.swift` — nouveau closure `sessionCount: () -> Int`, propagé à `SettingsView`
- `Sources/DofusSwitch/UI/SettingsView.swift` — reçoit `sessionCount: Int`, calcule `effectivelyEnabled`, affiche le hint conditionnel

---

## Task 1: Fonction pure `shouldEnableHotkeys` + tests

**Files:**
- Create: `Sources/DofusSwitchCore/HotkeyActivation.swift`
- Create: `Tests/DofusSwitchCoreTests/HotkeyActivationTests.swift`

- [ ] **Step 1: Écrire les tests avant l'implémentation**

Create `Tests/DofusSwitchCoreTests/HotkeyActivationTests.swift` :

```swift
// Tests/DofusSwitchCoreTests/HotkeyActivationTests.swift
import XCTest
@testable import DofusSwitchCore

final class HotkeyActivationTests: XCTestCase {
    func test_disabledWhenToggleOff_zeroSessions() {
        XCTAssertFalse(shouldEnableHotkeys(preferredEnabled: false, sessionCount: 0))
    }

    func test_disabledWhenToggleOff_oneSession() {
        XCTAssertFalse(shouldEnableHotkeys(preferredEnabled: false, sessionCount: 1))
    }

    func test_disabledWhenToggleOff_manySessions() {
        XCTAssertFalse(shouldEnableHotkeys(preferredEnabled: false, sessionCount: 5))
    }

    func test_disabledWhenToggleOn_zeroSessions() {
        XCTAssertFalse(shouldEnableHotkeys(preferredEnabled: true, sessionCount: 0))
    }

    func test_disabledWhenToggleOn_oneSession() {
        XCTAssertFalse(shouldEnableHotkeys(preferredEnabled: true, sessionCount: 1))
    }

    func test_enabledWhenToggleOn_twoSessions() {
        XCTAssertTrue(shouldEnableHotkeys(preferredEnabled: true, sessionCount: 2))
    }

    func test_enabledWhenToggleOn_manySessions() {
        XCTAssertTrue(shouldEnableHotkeys(preferredEnabled: true, sessionCount: 10))
    }

    func test_minimumSessionsConstantIsTwo() {
        XCTAssertEqual(hotkeyMinimumSessions, 2)
    }
}
```

- [ ] **Step 2: Régénérer le projet Xcode (xcodegen pick up le nouveau fichier)**

Run: `cd /Users/jbaubree/Projets/DofusSwitch && xcodegen generate`
Expected: exit code 0, aucun warning sur les sources manquantes.

- [ ] **Step 3: Lancer les tests pour confirmer qu'ils échouent (symbole inexistant)**

Run: `cd /Users/jbaubree/Projets/DofusSwitch && xcodebuild test -scheme DofusSwitch -destination 'platform=macOS' -only-testing:DofusSwitchCoreTests/HotkeyActivationTests 2>&1 | tail -30`
Expected: erreur de compilation `cannot find 'shouldEnableHotkeys' in scope` ou `cannot find 'hotkeyMinimumSessions' in scope`.

- [ ] **Step 4: Écrire l'implémentation minimale**

Create `Sources/DofusSwitchCore/HotkeyActivation.swift` :

```swift
// Sources/DofusSwitchCore/HotkeyActivation.swift
import Foundation

/// Nombre minimum de sessions Dofus détectées pour que les raccourcis globaux
/// soient enregistrés auprès de Carbon.
public let hotkeyMinimumSessions: Int = 2

/// Règle d'activation effective des raccourcis globaux.
///
/// Les raccourcis sont enregistrés si et seulement si l'utilisateur les a
/// activés dans les préférences ET qu'au moins `hotkeyMinimumSessions`
/// sessions Dofus sont actuellement détectées.
public func shouldEnableHotkeys(preferredEnabled: Bool, sessionCount: Int) -> Bool {
    preferredEnabled && sessionCount >= hotkeyMinimumSessions
}
```

- [ ] **Step 5: Régénérer puis relancer les tests**

Run: `cd /Users/jbaubree/Projets/DofusSwitch && xcodegen generate && xcodebuild test -scheme DofusSwitch -destination 'platform=macOS' -only-testing:DofusSwitchCoreTests/HotkeyActivationTests 2>&1 | tail -20`
Expected: `** TEST SUCCEEDED **` avec 8 tests passés (7 cas table + constant check).

- [ ] **Step 6: Commit**

```bash
cd /Users/jbaubree/Projets/DofusSwitch
git add Sources/DofusSwitchCore/HotkeyActivation.swift Tests/DofusSwitchCoreTests/HotkeyActivationTests.swift
git commit -m "feat(core): add shouldEnableHotkeys activation rule"
```

---

## Task 2: Brancher la fonction dans `AppDelegate`

**Files:**
- Modify: `Sources/DofusSwitch/AppDelegate.swift:26-30` (callback `detector.onUpdate`)
- Modify: `Sources/DofusSwitch/AppDelegate.swift:107-113` (méthode `applyHotkeyState`)

- [ ] **Step 1: Modifier `applyHotkeyState` pour consulter la fonction pure**

In `Sources/DofusSwitch/AppDelegate.swift`, remplacer la méthode `applyHotkeyState()` par :

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

- [ ] **Step 2: Modifier `detector.onUpdate` pour déclencher la réévaluation**

In `Sources/DofusSwitch/AppDelegate.swift`, remplacer le bloc `detector.onUpdate = { ... }` dans `applicationDidFinishLaunching` par :

```swift
        // Detector → store (+ refresh menu bar icon when Dofus launches/quits,
        // + re-evaluate hotkey registration when the session count changes).
        detector.onUpdate = { [weak self] windows in
            guard let self else { return }
            self.windowStore.update(detected: windows)
            self.menuBar?.refreshIcon()
            self.applyHotkeyState()
        }
        detector.scanNow()
```

- [ ] **Step 3: Compiler l'app pour valider**

Run: `cd /Users/jbaubree/Projets/DofusSwitch && xcodebuild -scheme DofusSwitch -configuration Debug build 2>&1 | tail -10`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Relancer la suite de tests Core (vérifier qu'on n'a rien cassé)**

Run: `cd /Users/jbaubree/Projets/DofusSwitch && xcodebuild test -scheme DofusSwitch -destination 'platform=macOS' 2>&1 | tail -20`
Expected: `** TEST SUCCEEDED **`, tous les tests passent (30 anciens + 8 nouveaux ≈ 38 cas).

- [ ] **Step 5: Commit**

```bash
cd /Users/jbaubree/Projets/DofusSwitch
git add Sources/DofusSwitch/AppDelegate.swift
git commit -m "feat(app): auto-disable hotkeys below 2 Dofus sessions"
```

---

## Task 3: Propager `sessionCount` jusqu'à `SettingsView`

**Files:**
- Modify: `Sources/DofusSwitch/UI/PopoverRootView.swift:10-16` (ajout closure `sessionCount`), `:27-34` (propagation)
- Modify: `Sources/DofusSwitch/UI/SettingsView.swift:5-11` (nouvelle propriété `sessionCount`)
- Modify: `Sources/DofusSwitch/AppDelegate.swift:45-70` (passer `sessionCount` au `PopoverRootView`)

Cette task fait seulement passer la donnée. L'affichage du hint vient en Task 4.

- [ ] **Step 1: Ajouter le closure `sessionCount` à `PopoverRootView`**

In `Sources/DofusSwitch/UI/PopoverRootView.swift`, remplacer la liste des propriétés par :

```swift
    @ObservedObject var store: WindowStore
    @State private var showSettings = false
    @State private var axGranted: Bool = AccessibilityPermission.isTrusted(prompt: false)

    let currentWindowKey: () -> String?
    let sessionCount: () -> Int
    @Binding var nextHotkey: HotkeyBinding
    @Binding var prevHotkey: HotkeyBinding
    @Binding var launchAtLogin: Bool
    @Binding var hotkeysEnabled: Bool
    let onReset: () -> Void
    let onQuit: () -> Void
```

Puis dans `body`, remplacer l'appel à `SettingsView(...)` par :

```swift
                SettingsView(
                    nextHotkey: $nextHotkey,
                    prevHotkey: $prevHotkey,
                    launchAtLogin: $launchAtLogin,
                    hotkeysEnabled: $hotkeysEnabled,
                    sessionCount: sessionCount(),
                    onReset: onReset
                )
```

- [ ] **Step 2: Ajouter la propriété `sessionCount` à `SettingsView`**

In `Sources/DofusSwitch/UI/SettingsView.swift`, remplacer le bloc de propriétés par :

```swift
struct SettingsView: View {
    @Binding var nextHotkey: HotkeyBinding
    @Binding var prevHotkey: HotkeyBinding
    @Binding var launchAtLogin: Bool
    @Binding var hotkeysEnabled: Bool
    let sessionCount: Int
    var onReset: () -> Void
```

Note : on ajoute juste la propriété ici. Le hint et le changement d'opacité viennent en Task 4.

- [ ] **Step 3: Fournir le `sessionCount` depuis `AppDelegate`**

In `Sources/DofusSwitch/AppDelegate.swift`, dans `applicationDidFinishLaunching`, remplacer l'appel à `PopoverRootView(...)` par :

```swift
        let root = PopoverRootView(
            store: windowStore,
            currentWindowKey: { [weak self] in
                guard let self else { return nil }
                return self.cycleController.currentIndex(in: self.windowStore.visibleWindows)
                    .flatMap { self.windowStore.visibleWindows[$0].normalizedKey }
            },
            sessionCount: { [weak self] in
                self?.windowStore.visibleWindows.count ?? 0
            },
            nextHotkey: Binding(
                get: { self.prefs.nextHotkey },
                set: { self.updateNextHotkey($0) }
            ),
            prevHotkey: Binding(
                get: { self.prefs.prevHotkey },
                set: { self.updatePrevHotkey($0) }
            ),
            launchAtLogin: Binding(
                get: { self.prefs.launchAtLogin },
                set: { self.updateLaunchAtLogin($0) }
            ),
            hotkeysEnabled: Binding(
                get: { self.prefs.hotkeysEnabled },
                set: { self.updateHotkeysEnabled($0) }
            ),
            onReset: { [weak self] in self?.resetToDefaults() },
            onQuit: { NSApp.terminate(nil) }
        )
```

- [ ] **Step 4: Compiler l'app**

Run: `cd /Users/jbaubree/Projets/DofusSwitch && xcodebuild -scheme DofusSwitch -configuration Debug build 2>&1 | tail -10`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
cd /Users/jbaubree/Projets/DofusSwitch
git add Sources/DofusSwitch/AppDelegate.swift Sources/DofusSwitch/UI/PopoverRootView.swift Sources/DofusSwitch/UI/SettingsView.swift
git commit -m "refactor(ui): plumb sessionCount from AppDelegate to SettingsView"
```

---

## Task 4: Afficher le hint + opacité conditionnelle dans `SettingsView`

**Files:**
- Modify: `Sources/DofusSwitch/UI/SettingsView.swift` (ajouter `effectivelyEnabled`, remplacer `.opacity`, insérer le hint)

- [ ] **Step 1: Importer `DofusSwitchCore` et ajouter la propriété calculée**

In `Sources/DofusSwitch/UI/SettingsView.swift`, l'import `DofusSwitchCore` est déjà présent. Dans le `struct SettingsView`, ajouter juste avant `var body: some View` :

```swift
    private var effectivelyEnabled: Bool {
        shouldEnableHotkeys(preferredEnabled: hotkeysEnabled, sessionCount: sessionCount)
    }

    private var showLowSessionHint: Bool {
        hotkeysEnabled && sessionCount < hotkeyMinimumSessions
    }
```

- [ ] **Step 2: Remplacer intégralement le `body` par la version avec hint**

In `Sources/DofusSwitch/UI/SettingsView.swift`, remplacer `var body: some View { ... }` par :

```swift
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Raccourcis globaux").font(.headline)
                Spacer()
                Toggle("", isOn: $hotkeysEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            HStack {
                Text("Fenêtre suivante")
                Spacer()
                HotkeyRecorderField(binding: $nextHotkey, label: "next")
                    .frame(width: 160, height: 24)
            }
            .opacity(effectivelyEnabled ? 1 : 0.4)
            HStack {
                Text("Fenêtre précédente")
                Spacer()
                HotkeyRecorderField(binding: $prevHotkey, label: "prev")
                    .frame(width: 160, height: 24)
            }
            .opacity(effectivelyEnabled ? 1 : 0.4)

            if showLowSessionHint {
                Text("Inactifs : lance au moins 2 clients Dofus.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Toggle("Démarrer au login", isOn: $launchAtLogin)

            Divider()

            Button("Réinitialiser") { onReset() }
                .buttonStyle(.borderless)
                .foregroundStyle(.red)

            Spacer()
        }
        .padding(16)
    }
```

- [ ] **Step 3: Compiler l'app**

Run: `cd /Users/jbaubree/Projets/DofusSwitch && xcodebuild -scheme DofusSwitch -configuration Debug build 2>&1 | tail -10`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Relancer toute la suite de tests pour confirmer non-régression**

Run: `cd /Users/jbaubree/Projets/DofusSwitch && xcodebuild test -scheme DofusSwitch -destination 'platform=macOS' 2>&1 | tail -20`
Expected: `** TEST SUCCEEDED **`, tous les tests passent (30 anciens + 8 nouveaux ≈ 38 cas).

- [ ] **Step 5: Test manuel (optionnel mais recommandé — demander à l'utilisateur de valider)**

Run: `make install` depuis `/Users/jbaubree/Projets/DofusSwitch`.

Scénarios à vérifier côté utilisateur :
1. **0 session Dofus + toggle ON** : ouvrir le popover → Settings. Le texte "Inactifs : lance au moins 2 clients Dofus." doit apparaître sous les lignes de raccourci. Les recorders doivent apparaître à opacity 0.4. Appuyer sur `⌃⌥→` dans une autre app → aucun effet.
2. **1 session Dofus + toggle ON** : même affichage. Raccourcis globaux inactifs.
3. **2 sessions Dofus + toggle ON** : le hint disparaît. Les recorders repassent à opacity 1. `⌃⌥→` cycle entre les fenêtres.
4. **Fermer une session (2 → 1) sans quitter l'app** : dans les 2 secondes (polling), le hint réapparaît et `⌃⌥→` ne fait plus rien.
5. **Toggle OFF, quel que soit le count** : les recorders restent à 0.4 et le hint NE s'affiche PAS (il est conditionné par `hotkeysEnabled == true`).

- [ ] **Step 6: Commit**

```bash
cd /Users/jbaubree/Projets/DofusSwitch
git add Sources/DofusSwitch/UI/SettingsView.swift
git commit -m "feat(ui): show low-session hint and dim recorders when auto-disabled"
```

---

## Vérification finale (self-check avant d'annoncer fini)

- [ ] Les 4 commits sont bien présents : `git log --oneline -4` doit montrer, du plus récent au plus ancien :
  - `feat(ui): show low-session hint and dim recorders when auto-disabled`
  - `refactor(ui): plumb sessionCount from AppDelegate to SettingsView`
  - `feat(app): auto-disable hotkeys below 2 Dofus sessions`
  - `feat(core): add shouldEnableHotkeys activation rule`

- [ ] Toute la suite de tests passe : `xcodebuild test -scheme DofusSwitch -destination 'platform=macOS'` → `** TEST SUCCEEDED **`.

- [ ] Build Debug clean : `xcodebuild -scheme DofusSwitch -configuration Debug build` → `** BUILD SUCCEEDED **`.

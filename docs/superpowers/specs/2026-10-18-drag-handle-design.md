# Poignée de drag visible dans WindowListView — Design Spec

**Date :** 2026-10-18
**Status :** Draft (en cours de validation utilisateur)

## 1. Contexte

Le drag-and-drop pour réordonner les fenêtres détectées est **déjà fonctionnel** :

- `WindowListView.swift:35` branche `.onMove` sur le `ForEach`
- `WindowStore.move(fromOffsets:toOffset:)` applique le réordonnancement et persiste via `PreferencesStore`
- `WindowStoreTests.test_move_persistsAndReorders` couvre le comportement du modèle

Mais la fonctionnalité n'est pas **découvrable** : rien dans la ligne ne signale à l'utilisateur qu'elle peut être déplacée.

## 2. Objectif

Rendre le drag-and-drop découvrable visuellement sans toucher au modèle ni au comportement de drag natif.

**Non-objectifs :**
- Changer la logique de réordonnancement
- Changer la persistance
- Afficher/masquer la poignée au hover
- Ajouter des animations custom (scale, shadow explicite) sur la ligne en cours de drag

## 3. Changement visuel

Chaque ligne de la liste passe de :

```
[AppIcon] [Title ................] [current dot?]
```

à :

```
[≡] [AppIcon] [Title ................] [current dot?]
```

où `≡` est un SF Symbol `line.3.horizontal`, teinté `.tertiary` pour rester discret, à la même taille que l'icône app (16 pt).

L'effet de surélévation pendant le drag est fourni par le **drag preview natif macOS** de `SwiftUI.List + .onMove` : ombre portée translucide, pas de code à ajouter.

## 4. Implémentation

**Fichiers touchés :** `Sources/DofusSwitch/UI/WindowListView.swift` uniquement.

**Diff conceptuel** dans le `HStack` du `ForEach` :

```swift
HStack(spacing: 8) {
    Image(systemName: "line.3.horizontal")
        .foregroundStyle(.tertiary)
        .frame(width: 16, height: 16)
    iconFor(pid: window.pid)
    Text(window.displayTitle).lineLimit(1)
    Spacer()
    if window.normalizedKey == currentWindowKey {
        Image(systemName: "dot.circle.fill")
            .foregroundStyle(.tint)
    }
}
```

**Note importante :** la poignée est **purement visuelle**. On ne lui attache pas `.onDrag` — sur macOS, `List + .onMove` capte déjà le drag sur toute la ligne, et dupliquer avec un `.onDrag` dédié à la poignée entrerait en conflit. L'icône sert d'indice d'affordance, rien de plus.

## 5. Tests

Aucun test à ajouter. Les tests existants couvrent le modèle (`WindowStoreTests`), et la poignée est purement visuelle — pas de logique à tester.

## 6. Risque et plan de repli

**Risque :** si à l'usage le drag preview natif macOS s'avère trop discret visuellement, l'effet de surélévation ne sera pas perceptible malgré la poignée.

**Plan de repli (hors scope de ce ticket) :** basculer sur une implémentation custom `.onDrag` + `.onDrop` avec `NSItemProvider`, en traquant un `@State var draggedKey: String?` pour appliquer `.shadow` + `.scaleEffect` explicites. Nécessiterait de re-vérifier que la persistance et les tests existants restent valides.

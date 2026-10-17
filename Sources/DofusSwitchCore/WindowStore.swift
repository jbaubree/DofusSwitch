// Sources/DofusSwitchCore/WindowStore.swift
import Foundation
import Combine

public final class WindowStore: ObservableObject {
    @Published public private(set) var visibleWindows: [TrackedWindow] = []
    public private(set) var persistedOrder: [String] = []

    private let preferencesStore: PreferencesStore

    public init(preferencesStore: PreferencesStore) {
        self.preferencesStore = preferencesStore
        self.persistedOrder = preferencesStore.load().windowOrder
    }

    /// Replace the current detected set and recompute visible order.
    public func update(detected: [TrackedWindow]) {
        let byKey = Dictionary(uniqueKeysWithValues: detected.map { ($0.normalizedKey, $0) })

        // 1. Known windows in persisted order.
        var ordered: [TrackedWindow] = []
        var consumed = Set<String>()
        for key in persistedOrder {
            if let win = byKey[key] {
                ordered.append(win)
                consumed.insert(key)
            }
        }

        // 2. New windows (not yet in persistedOrder), appended in detected order.
        for win in detected where !consumed.contains(win.normalizedKey) {
            ordered.append(win)
            persistedOrder.append(win.normalizedKey)
        }

        visibleWindows = ordered
        persistCurrentOrder()
    }

    public func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        // Pure Swift manual move — move(fromOffsets:toOffset:) requires SwiftUI import.
        let moving = source.map { visibleWindows[$0] }
        var result: [TrackedWindow] = []
        result.reserveCapacity(visibleWindows.count)
        // Adjust destination: how many source indices are strictly before destination
        let insertAt = destination - source.filter { $0 < destination }.count
        var insertedMoving = false
        for (idx, item) in visibleWindows.enumerated() {
            if result.count == insertAt && !insertedMoving {
                result.append(contentsOf: moving)
                insertedMoving = true
            }
            if !source.contains(idx) {
                result.append(item)
            }
        }
        // Handle insertion at end
        if !insertedMoving {
            result.append(contentsOf: moving)
        }
        visibleWindows = result
        // Rebuild persistedOrder: visible keys in their new order,
        // then phantom keys (preserved) in their previous relative order.
        let visibleKeys = visibleWindows.map(\.normalizedKey)
        let visibleKeySet = Set(visibleKeys)
        let phantoms = persistedOrder.filter { !visibleKeySet.contains($0) }
        persistedOrder = visibleKeys + phantoms
        persistCurrentOrder()
    }

    private func persistCurrentOrder() {
        var prefs = preferencesStore.load()
        prefs.windowOrder = persistedOrder
        preferencesStore.save(prefs)
    }
}

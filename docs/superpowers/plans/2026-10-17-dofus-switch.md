# DofusSwitch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a minimalist macOS menu-bar app that cycles focus between Dofus Unity windows via two global hotkeys.

**Architecture:** Swift native, AppKit shell with SwiftUI popover. Core domain logic (window tracking, cycling, preferences) is in a testable library target. The executable target wires everything to `NSStatusItem`, Carbon hotkeys, and the Accessibility API.

**Tech Stack:** Swift 5.9+, macOS 13+ (Ventura), AppKit + SwiftUI, Carbon.HIToolbox (hotkeys), Accessibility API (window ops), ServiceManagement (`SMAppService` for launch-at-login), XcodeGen (project generation), XCTest.

**Spec:** `docs/superpowers/specs/2026-10-17-dofus-switch-design.md`

**Prerequisites:**
- Xcode 15+ installed
- `brew install xcodegen`
- Dofus Unity installed and runnable (needed for manual smoke tests from Task 7 onward)

---

## File Structure

The project uses **XcodeGen** so `.xcodeproj` is generated from `project.yml`. Two targets:

- **DofusSwitchCore** (library) — all testable domain logic
- **DofusSwitch** (executable, `.app`) — AppKit/SwiftUI wiring

```
DofusSwitch/
├── project.yml                           # XcodeGen config
├── Info.plist                            # LSUIElement, usage descriptions
├── Sources/
│   ├── DofusSwitchCore/
│   │   ├── TrackedWindow.swift
│   │   ├── HotkeyBinding.swift
│   │   ├── Preferences.swift
│   │   ├── PreferencesStore.swift
│   │   ├── WindowStore.swift
│   │   └── CycleController.swift
│   └── DofusSwitch/
│       ├── DofusSwitchApp.swift          # @main entry
│       ├── AppDelegate.swift
│       ├── MenuBar/
│       │   ├── MenuBarController.swift
│       │   └── HotkeyRecorderField.swift
│       ├── Services/
│       │   ├── WindowDetector.swift      # AX API + NSWorkspace
│       │   ├── HotkeyManager.swift       # Carbon
│       │   ├── FocusService.swift        # AX activate/raise
│       │   └── LaunchAtLoginService.swift
│       └── UI/
│           ├── PopoverRootView.swift
│           ├── WindowListView.swift
│           ├── SettingsView.swift
│           └── OnboardingView.swift
├── Tests/
│   └── DofusSwitchCoreTests/
│       ├── TrackedWindowTests.swift
│       ├── HotkeyBindingTests.swift
│       ├── PreferencesTests.swift
│       ├── WindowStoreTests.swift
│       └── CycleControllerTests.swift
└── README.md
```

**Why two targets:** AX/Carbon code can't be meaningfully unit-tested (needs system-level access, running Dofus, hotkey registration). The core target holds everything that CAN be tested; the exec target holds the thin side-effect glue.

---

## Task 0: Project scaffolding with XcodeGen

**Files:**
- Create: `/Users/jbaubree/Projets/DofusSwitch/project.yml`
- Create: `/Users/jbaubree/Projets/DofusSwitch/Sources/DofusSwitch/DofusSwitchApp.swift`
- Create: `/Users/jbaubree/Projets/DofusSwitch/Sources/DofusSwitch/AppDelegate.swift`
- Create: `/Users/jbaubree/Projets/DofusSwitch/Sources/DofusSwitchCore/.gitkeep`
- Create: `/Users/jbaubree/Projets/DofusSwitch/Tests/DofusSwitchCoreTests/.gitkeep`

- [ ] **Step 1: Verify XcodeGen installed**

Run: `which xcodegen && xcodegen --version`
Expected: path printed, version printed. If "not found" → run `brew install xcodegen`.

- [ ] **Step 2: Write `project.yml`**

```yaml
name: DofusSwitch
options:
  bundleIdPrefix: com.jbaubree
  deploymentTarget:
    macOS: "13.0"
  createIntermediateGroups: true
settings:
  base:
    SWIFT_VERSION: "5.9"
    MACOSX_DEPLOYMENT_TARGET: "13.0"
    ENABLE_HARDENED_RUNTIME: YES
    CODE_SIGN_STYLE: Automatic
    CODE_SIGN_IDENTITY: "-"            # ad-hoc signing
    DEVELOPMENT_TEAM: ""
targets:
  DofusSwitchCore:
    type: framework
    platform: macOS
    sources:
      - Sources/DofusSwitchCore
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.jbaubree.DofusSwitchCore
        SKIP_INSTALL: YES
        DEFINES_MODULE: YES
  DofusSwitch:
    type: application
    platform: macOS
    sources:
      - Sources/DofusSwitch
    info:
      path: Info.plist
      properties:
        LSUIElement: true
        NSHumanReadableCopyright: ""
        CFBundleShortVersionString: "0.1.0"
        CFBundleVersion: "1"
    dependencies:
      - target: DofusSwitchCore
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.jbaubree.DofusSwitch
  DofusSwitchCoreTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - Tests/DofusSwitchCoreTests
    dependencies:
      - target: DofusSwitchCore
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.jbaubree.DofusSwitchCoreTests
schemes:
  DofusSwitch:
    build:
      targets:
        DofusSwitch: all
        DofusSwitchCore: all
    run:
      config: Debug
    test:
      config: Debug
      targets:
        - DofusSwitchCoreTests
```

Note: `Info.plist` is generated by XcodeGen from the `info.properties` block above and written into the build output. **Do not create a hand-maintained Info.plist file at the repo root.**

- [ ] **Step 3: Write the minimal `DofusSwitchApp.swift`**

```swift
import SwiftUI

@main
struct DofusSwitchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Empty — all UI is in the menu bar popover, driven by AppDelegate.
        Settings { EmptyView() }
    }
}
```

- [ ] **Step 4: Write the minimal `AppDelegate.swift`**

```swift
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // belt and braces alongside LSUIElement
    }
}
```

- [ ] **Step 5: Add placeholders so XcodeGen does not fail on empty dirs**

Create empty files `Sources/DofusSwitchCore/.gitkeep` and `Tests/DofusSwitchCoreTests/.gitkeep`.

- [ ] **Step 6: Generate the Xcode project**

Run: `cd /Users/jbaubree/Projets/DofusSwitch && xcodegen generate`
Expected: `✅ Created project at DofusSwitch.xcodeproj`.

- [ ] **Step 7: Build**

Run: `cd /Users/jbaubree/Projets/DofusSwitch && xcodebuild -scheme DofusSwitch -configuration Debug build 2>&1 | tail -20`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 8: Add `DofusSwitch.xcodeproj` to `.gitignore`**

Append to `.gitignore`:
```
# XcodeGen output
DofusSwitch.xcodeproj/
```

- [ ] **Step 9: Commit**

```bash
cd /Users/jbaubree/Projets/DofusSwitch
git add project.yml Sources Tests .gitignore
git commit -m "chore: scaffold Xcode project via XcodeGen"
```

---

## Task 1: TrackedWindow value type

**Files:**
- Create: `Sources/DofusSwitchCore/TrackedWindow.swift`
- Test: `Tests/DofusSwitchCoreTests/TrackedWindowTests.swift`

A `TrackedWindow` is the in-memory representation of a detected Dofus window. The AX element is runtime-only; the normalized title is the persistence key.

- [ ] **Step 1: Write the failing test**

```swift
// Tests/DofusSwitchCoreTests/TrackedWindowTests.swift
import XCTest
@testable import DofusSwitchCore

final class TrackedWindowTests: XCTestCase {
    func test_normalizedKey_lowercasesAndTrims() {
        XCTAssertEqual(TrackedWindow.normalizedKey(from: "  Perso1  "), "perso1")
        XCTAssertEqual(TrackedWindow.normalizedKey(from: "PERSO1"), "perso1")
    }

    func test_normalizedKey_collapsesInternalWhitespace() {
        XCTAssertEqual(TrackedWindow.normalizedKey(from: "Perso  Un"), "perso un")
    }

    func test_normalizedKey_returnsEmptyStringForWhitespaceOnly() {
        XCTAssertEqual(TrackedWindow.normalizedKey(from: "   "), "")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/jbaubree/Projets/DofusSwitch && xcodegen generate && xcodebuild -scheme DofusSwitch test 2>&1 | tail -30`
Expected: compile error — `TrackedWindow` not defined.

- [ ] **Step 3: Write minimal implementation**

```swift
// Sources/DofusSwitchCore/TrackedWindow.swift
import Foundation

public struct TrackedWindow: Equatable, Identifiable {
    public let id: UUID
    public let title: String
    public let pid: pid_t
    public let axElementRef: AnyObject?   // AXUIElement; opaque at this layer

    public init(id: UUID = UUID(), title: String, pid: pid_t, axElementRef: AnyObject? = nil) {
        self.id = id
        self.title = title
        self.pid = pid
        self.axElementRef = axElementRef
    }

    public var normalizedKey: String {
        Self.normalizedKey(from: title)
    }

    public static func normalizedKey(from title: String) -> String {
        let lowered = title.lowercased()
        let trimmed = lowered.trimmingCharacters(in: .whitespacesAndNewlines)
        let collapsed = trimmed
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        return collapsed
    }

    public static func == (lhs: TrackedWindow, rhs: TrackedWindow) -> Bool {
        lhs.id == rhs.id && lhs.title == rhs.title && lhs.pid == rhs.pid
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/jbaubree/Projets/DofusSwitch && xcodegen generate && xcodebuild -scheme DofusSwitch test 2>&1 | tail -20`
Expected: `Test Suite 'TrackedWindowTests' passed`.

- [ ] **Step 5: Commit**

```bash
git add Sources/DofusSwitchCore/TrackedWindow.swift Tests/DofusSwitchCoreTests/TrackedWindowTests.swift
git commit -m "feat(core): add TrackedWindow with normalized key for persistence"
```

---

## Task 2: HotkeyBinding + Carbon modifier conversion

**Files:**
- Create: `Sources/DofusSwitchCore/HotkeyBinding.swift`
- Test: `Tests/DofusSwitchCoreTests/HotkeyBindingTests.swift`

Represents a serializable hotkey. Includes a conversion from `NSEvent.ModifierFlags` raw bits to the Carbon modifier mask that `RegisterEventHotKey` expects.

- [ ] **Step 1: Write the failing test**

```swift
// Tests/DofusSwitchCoreTests/HotkeyBindingTests.swift
import XCTest
@testable import DofusSwitchCore

final class HotkeyBindingTests: XCTestCase {
    // Carbon modifier constants (duplicated here to avoid importing Carbon in tests)
    private let cmdKey: UInt32 = 1 << 8
    private let shiftKey: UInt32 = 1 << 9
    private let optionKey: UInt32 = 1 << 11
    private let controlKey: UInt32 = 1 << 12

    // NSEvent raw masks (device-independent)
    private let nsCommand: UInt = 1 << 20
    private let nsShift: UInt = 1 << 17
    private let nsOption: UInt = 1 << 19
    private let nsControl: UInt = 1 << 18

    func test_carbonModifiers_fromNSEventFlags_singleModifiers() {
        XCTAssertEqual(HotkeyBinding.carbonModifiers(fromNSEventFlagsRaw: nsCommand), cmdKey)
        XCTAssertEqual(HotkeyBinding.carbonModifiers(fromNSEventFlagsRaw: nsShift), shiftKey)
        XCTAssertEqual(HotkeyBinding.carbonModifiers(fromNSEventFlagsRaw: nsOption), optionKey)
        XCTAssertEqual(HotkeyBinding.carbonModifiers(fromNSEventFlagsRaw: nsControl), controlKey)
    }

    func test_carbonModifiers_combined() {
        let combined = nsCommand | nsOption | nsControl
        XCTAssertEqual(
            HotkeyBinding.carbonModifiers(fromNSEventFlagsRaw: combined),
            cmdKey | optionKey | controlKey
        )
    }

    func test_defaultNext_isControlOptionRightArrow() {
        let b = HotkeyBinding.defaultNext
        XCTAssertEqual(b.keyCode, 0x7C) // kVK_RightArrow
        XCTAssertEqual(b.carbonModifiers, controlKey | optionKey)
    }

    func test_defaultPrev_isControlOptionLeftArrow() {
        let b = HotkeyBinding.defaultPrev
        XCTAssertEqual(b.keyCode, 0x7B) // kVK_LeftArrow
        XCTAssertEqual(b.carbonModifiers, controlKey | optionKey)
    }

    func test_codableRoundTrip() throws {
        let b = HotkeyBinding(keyCode: 0x24, carbonModifiers: cmdKey | shiftKey)
        let data = try JSONEncoder().encode(b)
        let decoded = try JSONDecoder().decode(HotkeyBinding.self, from: data)
        XCTAssertEqual(decoded, b)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/jbaubree/Projets/DofusSwitch && xcodegen generate && xcodebuild -scheme DofusSwitch test 2>&1 | tail -30`
Expected: compile error — `HotkeyBinding` not defined.

- [ ] **Step 3: Write minimal implementation**

```swift
// Sources/DofusSwitchCore/HotkeyBinding.swift
import Foundation

public struct HotkeyBinding: Codable, Equatable {
    public var keyCode: UInt32
    public var carbonModifiers: UInt32

    public init(keyCode: UInt32, carbonModifiers: UInt32) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
    }

    // Carbon modifier bits (from Carbon.HIToolbox.Events, duplicated so Core avoids Carbon import).
    public static let carbonCmd: UInt32    = 1 << 8
    public static let carbonShift: UInt32  = 1 << 9
    public static let carbonOption: UInt32 = 1 << 11
    public static let carbonControl: UInt32 = 1 << 12

    // NSEvent.ModifierFlags raw bit positions (stable, documented).
    private static let nsCommand: UInt = 1 << 20
    private static let nsShift: UInt   = 1 << 17
    private static let nsOption: UInt  = 1 << 19
    private static let nsControl: UInt = 1 << 18

    /// Converts raw `NSEvent.ModifierFlags.rawValue` bits to the Carbon modifier mask
    /// that `RegisterEventHotKey` expects.
    public static func carbonModifiers(fromNSEventFlagsRaw raw: UInt) -> UInt32 {
        var out: UInt32 = 0
        if raw & nsCommand != 0 { out |= carbonCmd }
        if raw & nsShift   != 0 { out |= carbonShift }
        if raw & nsOption  != 0 { out |= carbonOption }
        if raw & nsControl != 0 { out |= carbonControl }
        return out
    }

    public static let defaultNext = HotkeyBinding(
        keyCode: 0x7C, // kVK_RightArrow
        carbonModifiers: carbonControl | carbonOption
    )

    public static let defaultPrev = HotkeyBinding(
        keyCode: 0x7B, // kVK_LeftArrow
        carbonModifiers: carbonControl | carbonOption
    )
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/jbaubree/Projets/DofusSwitch && xcodebuild -scheme DofusSwitch test 2>&1 | tail -20`
Expected: `Test Suite 'HotkeyBindingTests' passed`.

- [ ] **Step 5: Commit**

```bash
git add Sources/DofusSwitchCore/HotkeyBinding.swift Tests/DofusSwitchCoreTests/HotkeyBindingTests.swift
git commit -m "feat(core): add HotkeyBinding with Carbon modifier conversion"
```

---

## Task 3: Preferences model + UserDefaults store

**Files:**
- Create: `Sources/DofusSwitchCore/Preferences.swift`
- Create: `Sources/DofusSwitchCore/PreferencesStore.swift`
- Test: `Tests/DofusSwitchCoreTests/PreferencesTests.swift`

`Preferences` is the Codable payload. `PreferencesStore` is a thin wrapper around a `UserDefaults` that stores it under a single key. Tests inject an in-memory `UserDefaults` so no system state is touched.

- [ ] **Step 1: Write the failing test**

```swift
// Tests/DofusSwitchCoreTests/PreferencesTests.swift
import XCTest
@testable import DofusSwitchCore

final class PreferencesTests: XCTestCase {
    private func makeStore() -> (PreferencesStore, UserDefaults) {
        let suite = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return (PreferencesStore(defaults: defaults), defaults)
    }

    func test_load_returnsDefaultsWhenEmpty() {
        let (store, _) = makeStore()
        let prefs = store.load()
        XCTAssertEqual(prefs.nextHotkey, .defaultNext)
        XCTAssertEqual(prefs.prevHotkey, .defaultPrev)
        XCTAssertEqual(prefs.windowOrder, [])
        XCTAssertFalse(prefs.launchAtLogin)
    }

    func test_save_thenLoad_roundTripsAllFields() {
        let (store, _) = makeStore()
        var prefs = Preferences.defaults
        prefs.windowOrder = ["perso1", "perso2"]
        prefs.launchAtLogin = true
        prefs.nextHotkey = HotkeyBinding(keyCode: 1, carbonModifiers: 2)
        store.save(prefs)

        let loaded = store.load()
        XCTAssertEqual(loaded, prefs)
    }

    func test_load_fallsBackToDefaultsOnCorruptData() {
        let (store, defaults) = makeStore()
        defaults.set(Data([0xFF, 0xFF]), forKey: PreferencesStore.storageKey)
        XCTAssertEqual(store.load(), .defaults)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/jbaubree/Projets/DofusSwitch && xcodegen generate && xcodebuild -scheme DofusSwitch test 2>&1 | tail -30`
Expected: compile error — `Preferences` / `PreferencesStore` not defined.

- [ ] **Step 3: Write `Preferences.swift`**

```swift
// Sources/DofusSwitchCore/Preferences.swift
import Foundation

public struct Preferences: Codable, Equatable {
    public var nextHotkey: HotkeyBinding
    public var prevHotkey: HotkeyBinding
    public var windowOrder: [String]   // normalized title keys
    public var launchAtLogin: Bool

    public init(nextHotkey: HotkeyBinding, prevHotkey: HotkeyBinding, windowOrder: [String], launchAtLogin: Bool) {
        self.nextHotkey = nextHotkey
        self.prevHotkey = prevHotkey
        self.windowOrder = windowOrder
        self.launchAtLogin = launchAtLogin
    }

    public static let defaults = Preferences(
        nextHotkey: .defaultNext,
        prevHotkey: .defaultPrev,
        windowOrder: [],
        launchAtLogin: false
    )
}
```

- [ ] **Step 4: Write `PreferencesStore.swift`**

```swift
// Sources/DofusSwitchCore/PreferencesStore.swift
import Foundation

public final class PreferencesStore {
    public static let storageKey = "com.jbaubree.DofusSwitch.preferences"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> Preferences {
        guard let data = defaults.data(forKey: Self.storageKey) else { return .defaults }
        return (try? JSONDecoder().decode(Preferences.self, from: data)) ?? .defaults
    }

    public func save(_ prefs: Preferences) {
        guard let data = try? JSONEncoder().encode(prefs) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd /Users/jbaubree/Projets/DofusSwitch && xcodebuild -scheme DofusSwitch test 2>&1 | tail -20`
Expected: `Test Suite 'PreferencesTests' passed`.

- [ ] **Step 6: Commit**

```bash
git add Sources/DofusSwitchCore/Preferences.swift Sources/DofusSwitchCore/PreferencesStore.swift Tests/DofusSwitchCoreTests/PreferencesTests.swift
git commit -m "feat(core): add Preferences model and UserDefaults-backed store"
```

---

## Task 4: WindowStore (merge detected × ordered)

**Files:**
- Create: `Sources/DofusSwitchCore/WindowStore.swift`
- Test: `Tests/DofusSwitchCoreTests/WindowStoreTests.swift`

`WindowStore` owns the authoritative ordered list. It merges newly detected windows with the persisted order, keeping "phantom" entries (persisted but currently absent) in the saved order so an ordering survives Dofus relaunches.

- [ ] **Step 1: Write the failing test**

```swift
// Tests/DofusSwitchCoreTests/WindowStoreTests.swift
import XCTest
@testable import DofusSwitchCore

final class WindowStoreTests: XCTestCase {
    private func makeStore(order: [String] = []) -> WindowStore {
        let defaults = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        let prefs = Preferences(
            nextHotkey: .defaultNext,
            prevHotkey: .defaultPrev,
            windowOrder: order,
            launchAtLogin: false
        )
        let prefsStore = PreferencesStore(defaults: defaults)
        prefsStore.save(prefs)
        return WindowStore(preferencesStore: prefsStore)
    }

    private func w(_ title: String, pid: pid_t = 1) -> TrackedWindow {
        TrackedWindow(title: title, pid: pid)
    }

    func test_update_withEmptyOrder_appendsInDetectedOrder() {
        let store = makeStore()
        store.update(detected: [w("Perso1"), w("Perso2")])
        XCTAssertEqual(store.visibleWindows.map(\.title), ["Perso1", "Perso2"])
    }

    func test_update_respectsPersistedOrder() {
        let store = makeStore(order: ["perso2", "perso1"])
        store.update(detected: [w("Perso1"), w("Perso2")])
        XCTAssertEqual(store.visibleWindows.map(\.title), ["Perso2", "Perso1"])
    }

    func test_update_newWindows_appendInDetectedOrderAfterKnown() {
        let store = makeStore(order: ["perso1"])
        store.update(detected: [w("Perso2"), w("Perso1"), w("Perso3")])
        XCTAssertEqual(store.visibleWindows.map(\.title), ["Perso1", "Perso2", "Perso3"])
    }

    func test_update_absentPersistedWindows_arePreservedButHidden() {
        let store = makeStore(order: ["perso1", "perso2", "perso3"])
        store.update(detected: [w("Perso2")])
        XCTAssertEqual(store.visibleWindows.map(\.title), ["Perso2"])
        XCTAssertEqual(store.persistedOrder, ["perso1", "perso2", "perso3"])
    }

    func test_move_persistsAndReorders() {
        let store = makeStore()
        store.update(detected: [w("A"), w("B"), w("C")])
        store.move(fromOffsets: IndexSet(integer: 0), toOffset: 3) // A → after C
        XCTAssertEqual(store.visibleWindows.map(\.title), ["B", "C", "A"])
        XCTAssertEqual(store.persistedOrder, ["b", "c", "a"])
    }

    func test_update_removesPhantomWhenNeverSeen_isDisabled() {
        // Behavior: phantoms are kept forever (purge is a user action, not automatic).
        let store = makeStore(order: ["ghost"])
        store.update(detected: [])
        XCTAssertEqual(store.persistedOrder, ["ghost"])
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/jbaubree/Projets/DofusSwitch && xcodegen generate && xcodebuild -scheme DofusSwitch test 2>&1 | tail -30`
Expected: compile error — `WindowStore` not defined.

- [ ] **Step 3: Write implementation**

```swift
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
        visibleWindows.move(fromOffsets: source, toOffset: destination)
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/jbaubree/Projets/DofusSwitch && xcodebuild -scheme DofusSwitch test 2>&1 | tail -20`
Expected: all `WindowStoreTests` pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/DofusSwitchCore/WindowStore.swift Tests/DofusSwitchCoreTests/WindowStoreTests.swift
git commit -m "feat(core): add WindowStore with ordered merge + phantom preservation"
```

---

## Task 5: CycleController

**Files:**
- Create: `Sources/DofusSwitchCore/CycleController.swift`
- Test: `Tests/DofusSwitchCoreTests/CycleControllerTests.swift`

Pure logic: given the current list of visible windows and a current index, compute the next/previous window. Does **not** perform focus; it returns the target `TrackedWindow` for the caller to focus.

- [ ] **Step 1: Write the failing test**

```swift
// Tests/DofusSwitchCoreTests/CycleControllerTests.swift
import XCTest
@testable import DofusSwitchCore

final class CycleControllerTests: XCTestCase {
    private func w(_ t: String) -> TrackedWindow { TrackedWindow(title: t, pid: 1) }

    func test_next_fromNoCurrent_returnsFirst() {
        let c = CycleController()
        let target = c.next(in: [w("A"), w("B"), w("C")])
        XCTAssertEqual(target?.title, "A")
    }

    func test_next_wrapsAtEnd() {
        let c = CycleController()
        _ = c.next(in: [w("A"), w("B")]) // currentKey = "a"
        _ = c.next(in: [w("A"), w("B")]) // currentKey = "b"
        let target = c.next(in: [w("A"), w("B")])
        XCTAssertEqual(target?.title, "A")
    }

    func test_prev_fromNoCurrent_returnsLast() {
        let c = CycleController()
        let target = c.prev(in: [w("A"), w("B"), w("C")])
        XCTAssertEqual(target?.title, "C")
    }

    func test_prev_wrapsAtStart() {
        let c = CycleController()
        _ = c.next(in: [w("A"), w("B")]) // currentKey = "a"
        let target = c.prev(in: [w("A"), w("B")])
        XCTAssertEqual(target?.title, "B")
    }

    func test_emptyList_returnsNil() {
        let c = CycleController()
        XCTAssertNil(c.next(in: []))
        XCTAssertNil(c.prev(in: []))
    }

    func test_singleElement_alwaysReturnsThatElement() {
        let c = CycleController()
        XCTAssertEqual(c.next(in: [w("Only")])?.title, "Only")
        XCTAssertEqual(c.next(in: [w("Only")])?.title, "Only")
        XCTAssertEqual(c.prev(in: [w("Only")])?.title, "Only")
    }

    func test_currentNoLongerPresent_restartsAtFirstForNext() {
        let c = CycleController()
        _ = c.next(in: [w("A"), w("B")]) // currentKey = "a"
        let target = c.next(in: [w("C"), w("D")]) // "a" absent
        XCTAssertEqual(target?.title, "C")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/jbaubree/Projets/DofusSwitch && xcodegen generate && xcodebuild -scheme DofusSwitch test 2>&1 | tail -30`
Expected: compile error — `CycleController` not defined.

- [ ] **Step 3: Write implementation**

```swift
// Sources/DofusSwitchCore/CycleController.swift
import Foundation

public final class CycleController {
    private var currentKey: String?

    public init() {}

    public func next(in windows: [TrackedWindow]) -> TrackedWindow? {
        pickAndMark(in: windows, offset: 1)
    }

    public func prev(in windows: [TrackedWindow]) -> TrackedWindow? {
        pickAndMark(in: windows, offset: -1)
    }

    public func currentIndex(in windows: [TrackedWindow]) -> Int? {
        guard let key = currentKey else { return nil }
        return windows.firstIndex(where: { $0.normalizedKey == key })
    }

    private func pickAndMark(in windows: [TrackedWindow], offset: Int) -> TrackedWindow? {
        guard !windows.isEmpty else { return nil }
        let target: TrackedWindow?
        if let key = currentKey,
           let idx = windows.firstIndex(where: { $0.normalizedKey == key }) {
            let n = windows.count
            let next = ((idx + offset) % n + n) % n
            target = windows[next]
        } else {
            target = offset >= 0 ? windows.first : windows.last
        }
        currentKey = target?.normalizedKey
        return target
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/jbaubree/Projets/DofusSwitch && xcodebuild -scheme DofusSwitch test 2>&1 | tail -20`
Expected: all `CycleControllerTests` pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/DofusSwitchCore/CycleController.swift Tests/DofusSwitchCoreTests/CycleControllerTests.swift
git commit -m "feat(core): add CycleController with wrap-around and empty handling"
```

---

## Task 6: HotkeyManager (Carbon global hotkeys)

**Files:**
- Create: `Sources/DofusSwitch/Services/HotkeyManager.swift`

Carbon's `RegisterEventHotKey` + a single shared `InstallEventHandler` dispatching by `hotKeyID`. Not unit-tested — exercised via the manual smoke test at the end.

- [ ] **Step 1: Write implementation**

```swift
// Sources/DofusSwitch/Services/HotkeyManager.swift
import Carbon.HIToolbox
import DofusSwitchCore

public enum HotkeyID: UInt32 {
    case next = 1
    case prev = 2
}

public final class HotkeyManager {
    public var onHotkey: ((HotkeyID) -> Void)?

    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var handlerRef: EventHandlerRef?

    public init() {
        installHandler()
    }

    deinit {
        if let handlerRef { RemoveEventHandler(handlerRef) }
        for (_, ref) in refs { UnregisterEventHotKey(ref) }
    }

    public func rebind(next: HotkeyBinding, prev: HotkeyBinding) {
        unregister(.next)
        unregister(.prev)
        register(id: .next, binding: next)
        register(id: .prev, binding: prev)
    }

    private func register(id: HotkeyID, binding: HotkeyBinding) {
        var hotKeyID = EventHotKeyID(signature: OSType(0x44535748 /* 'DSWH' */), id: id.rawValue)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            binding.keyCode,
            binding.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if status == noErr, let ref {
            refs[id.rawValue] = ref
        } else {
            NSLog("DofusSwitch: RegisterEventHotKey failed for id=\(id) status=\(status)")
        }
    }

    private func unregister(_ id: HotkeyID) {
        if let ref = refs.removeValue(forKey: id.rawValue) {
            UnregisterEventHotKey(ref)
        }
    }

    private func installHandler() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }
                var id = EventHotKeyID()
                let s = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &id
                )
                guard s == noErr else { return noErr }
                let mgr = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                if let hk = HotkeyID(rawValue: id.id) {
                    DispatchQueue.main.async { mgr.onHotkey?(hk) }
                }
                return noErr
            },
            1,
            &spec,
            selfPtr,
            &handlerRef
        )
    }
}
```

- [ ] **Step 2: Verify the project builds**

Run: `cd /Users/jbaubree/Projets/DofusSwitch && xcodegen generate && xcodebuild -scheme DofusSwitch build 2>&1 | tail -20`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add Sources/DofusSwitch/Services/HotkeyManager.swift
git commit -m "feat: add HotkeyManager wrapping Carbon RegisterEventHotKey"
```

---

## Task 7: WindowDetector (Accessibility API + NSWorkspace)

**Files:**
- Create: `Sources/DofusSwitch/Services/WindowDetector.swift`

Discovers running Dofus Unity instances and their windows via AX, publishes `[TrackedWindow]` to a callback. Uses NSWorkspace notifications for app launch/quit, per-app AXObserver for window events, and a 2s poll as safety net.

> **Important first-run discovery step:** The actual Dofus Unity bundle identifier on macOS is not stated here as fact. Step 1 of this task is to find it with the running game.

- [ ] **Step 1: Discover Dofus bundle ID**

With Dofus Unity running, in a terminal:
```bash
osascript -e 'tell application "System Events" to get bundle identifier of every process whose name contains "Dofus"'
```
Expected: a bundle id like `com.ankama.dofus` printed. **Record this value and substitute it into the `isDofusApp(_:)` function below** before building.

If multiple processes are returned (helper processes, GPU process, etc.), prefer the one whose `name` is just "Dofus" and that has a visible AX window.

- [ ] **Step 2: Also inspect window titles**

```bash
osascript -e 'tell application "System Events" to get name of every window of every process whose name is "Dofus"'
```
Record a typical title (e.g. `Perso1 - 3.0.0.0`). If the title does not contain the character name, the normalized-title persistence key will not be stable across launches; this is called out as a known risk in the spec.

- [ ] **Step 3: Write implementation**

```swift
// Sources/DofusSwitch/Services/WindowDetector.swift
import AppKit
import ApplicationServices
import DofusSwitchCore

public final class WindowDetector {
    public var onUpdate: (([TrackedWindow]) -> Void)?

    // ⚠️ Substitute the bundle id discovered in Step 1 before shipping.
    private let dofusBundleId = "com.ankama.dofus"

    private var observers: [pid_t: AXObserver] = [:]
    private var pollTimer: Timer?

    public init() {
        subscribeWorkspace()
        startPolling()
    }

    deinit {
        pollTimer?.invalidate()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        for (_, obs) in observers {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(),
                                  AXObserverGetRunLoopSource(obs),
                                  .defaultMode)
        }
    }

    public func scanNow() {
        let detected = currentDofusApps().flatMap { trackedWindows(for: $0) }
        onUpdate?(detected)
        syncObservers()
    }

    // MARK: - NSWorkspace

    private func subscribeWorkspace() {
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(forName: NSWorkspace.didLaunchApplicationNotification,
                       object: nil, queue: .main) { [weak self] _ in self?.scanNow() }
        nc.addObserver(forName: NSWorkspace.didTerminateApplicationNotification,
                       object: nil, queue: .main) { [weak self] _ in self?.scanNow() }
    }

    private func currentDofusApps() -> [NSRunningApplication] {
        NSWorkspace.shared.runningApplications.filter(isDofusApp)
    }

    private func isDofusApp(_ app: NSRunningApplication) -> Bool {
        app.bundleIdentifier == dofusBundleId
    }

    // MARK: - AX API

    private func trackedWindows(for app: NSRunningApplication) -> [TrackedWindow] {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var value: AnyObject?
        let s = AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &value)
        guard s == .success, let axWindows = value as? [AXUIElement] else { return [] }

        return axWindows.compactMap { axWindow -> TrackedWindow? in
            var titleRef: AnyObject?
            guard AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleRef) == .success,
                  let title = titleRef as? String,
                  !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { return nil }
            return TrackedWindow(
                title: title,
                pid: app.processIdentifier,
                axElementRef: axWindow as AnyObject
            )
        }
    }

    // MARK: - AX observers per app

    private func syncObservers() {
        let currentPids = Set(currentDofusApps().map(\.processIdentifier))
        // Remove observers for dead apps.
        for (pid, obs) in observers where !currentPids.contains(pid) {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(),
                                  AXObserverGetRunLoopSource(obs),
                                  .defaultMode)
            observers.removeValue(forKey: pid)
        }
        // Add observers for new apps.
        for pid in currentPids where observers[pid] == nil {
            installObserver(pid: pid)
        }
    }

    private func installObserver(pid: pid_t) {
        var observer: AXObserver?
        let s = AXObserverCreate(pid, { _, _, _, refcon in
            guard let refcon else { return }
            let detector = Unmanaged<WindowDetector>.fromOpaque(refcon).takeUnretainedValue()
            DispatchQueue.main.async { detector.scanNow() }
        }, &observer)
        guard s == .success, let observer else { return }

        let axApp = AXUIElementCreateApplication(pid)
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        for notif in [kAXWindowCreatedNotification, kAXUIElementDestroyedNotification, kAXTitleChangedNotification] {
            AXObserverAddNotification(observer, axApp, notif as CFString, selfPtr)
        }
        CFRunLoopAddSource(CFRunLoopGetCurrent(),
                          AXObserverGetRunLoopSource(observer),
                          .defaultMode)
        observers[pid] = observer
    }

    // MARK: - Fallback poll

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.scanNow()
        }
    }
}
```

- [ ] **Step 4: Build**

Run: `cd /Users/jbaubree/Projets/DofusSwitch && xcodegen generate && xcodebuild -scheme DofusSwitch build 2>&1 | tail -20`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add Sources/DofusSwitch/Services/WindowDetector.swift
git commit -m "feat: add WindowDetector using NSWorkspace + AXObserver + 2s fallback poll"
```

---

## Task 8: FocusService

**Files:**
- Create: `Sources/DofusSwitch/Services/FocusService.swift`

Set main → raise → activate app, in that order, to minimize visual flashing.

- [ ] **Step 1: Write implementation**

```swift
// Sources/DofusSwitch/Services/FocusService.swift
import AppKit
import ApplicationServices
import DofusSwitchCore

public final class FocusService {
    public init() {}

    @discardableResult
    public func focus(_ window: TrackedWindow) -> Bool {
        guard let axRef = window.axElementRef else { return false }
        let axWindow = axRef as! AXUIElement

        _ = AXUIElementSetAttributeValue(axWindow, kAXMainAttribute as CFString, kCFBooleanTrue)
        _ = AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)

        guard let app = NSRunningApplication(processIdentifier: window.pid) else { return false }
        app.activate(options: [.activateIgnoringOtherApps])
        return true
    }
}
```

- [ ] **Step 2: Build**

Run: `cd /Users/jbaubree/Projets/DofusSwitch && xcodegen generate && xcodebuild -scheme DofusSwitch build 2>&1 | tail -20`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add Sources/DofusSwitch/Services/FocusService.swift
git commit -m "feat: add FocusService for AX-based window raise + app activate"
```

---

## Task 9: LaunchAtLoginService

**Files:**
- Create: `Sources/DofusSwitch/Services/LaunchAtLoginService.swift`

Thin wrapper around `SMAppService.mainApp` (macOS 13+).

- [ ] **Step 1: Write implementation**

```swift
// Sources/DofusSwitch/Services/LaunchAtLoginService.swift
import ServiceManagement

public final class LaunchAtLoginService {
    public init() {}

    public var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    public func set(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("DofusSwitch: launch-at-login change failed: \(error)")
        }
    }
}
```

- [ ] **Step 2: Build**

Run: `cd /Users/jbaubree/Projets/DofusSwitch && xcodegen generate && xcodebuild -scheme DofusSwitch build 2>&1 | tail -20`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add Sources/DofusSwitch/Services/LaunchAtLoginService.swift
git commit -m "feat: add LaunchAtLoginService using SMAppService"
```

---

## Task 10: OnboardingView (Accessibility permission)

**Files:**
- Create: `Sources/DofusSwitch/UI/OnboardingView.swift`

Shown when the AX permission check fails. Button opens the exact System Settings pane.

- [ ] **Step 1: Write implementation**

```swift
// Sources/DofusSwitch/UI/OnboardingView.swift
import SwiftUI
import ApplicationServices

struct OnboardingView: View {
    var onRecheck: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Autorisation requise")
                .font(.headline)
            Text("DofusSwitch a besoin de la permission Accessibilité pour détecter et focaliser les fenêtres Dofus.")
                .font(.system(size: 12))
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Ouvrir Réglages Système") { openSettings() }
                Button("Revérifier") { onRecheck() }
            }
        }
        .padding(16)
        .frame(width: 280)
    }

    private func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

enum AccessibilityPermission {
    static func isTrusted(prompt: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: prompt] as CFDictionary)
    }
}
```

- [ ] **Step 2: Build**

Run: `cd /Users/jbaubree/Projets/DofusSwitch && xcodegen generate && xcodebuild -scheme DofusSwitch build 2>&1 | tail -20`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add Sources/DofusSwitch/UI/OnboardingView.swift
git commit -m "feat(ui): add Accessibility permission onboarding view"
```

---

## Task 11: WindowListView

**Files:**
- Create: `Sources/DofusSwitch/UI/WindowListView.swift`

SwiftUI `List` with `.onMove`, uses `WindowStore` as `@ObservedObject`.

- [ ] **Step 1: Write implementation**

```swift
// Sources/DofusSwitch/UI/WindowListView.swift
import SwiftUI
import DofusSwitchCore

struct WindowListView: View {
    @ObservedObject var store: WindowStore
    var currentWindowKey: String?

    var body: some View {
        if store.visibleWindows.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "rectangle.3.offgrid.bubble.left")
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
                Text("Aucune fenêtre Dofus détectée")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(store.visibleWindows) { window in
                    HStack(spacing: 8) {
                        Image(systemName: "gamecontroller")
                            .foregroundStyle(.secondary)
                        Text(window.title).lineLimit(1)
                        Spacer()
                        if window.normalizedKey == currentWindowKey {
                            Image(systemName: "dot.circle.fill")
                                .foregroundStyle(.tint)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .onMove { offsets, destination in
                    store.move(fromOffsets: offsets, toOffset: destination)
                }
            }
            .listStyle(.inset)
        }
    }
}
```

- [ ] **Step 2: Build**

Run: `cd /Users/jbaubree/Projets/DofusSwitch && xcodegen generate && xcodebuild -scheme DofusSwitch build 2>&1 | tail -20`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add Sources/DofusSwitch/UI/WindowListView.swift
git commit -m "feat(ui): add reorderable WindowListView with current indicator"
```

---

## Task 12: HotkeyRecorderField (NSView bridge)

**Files:**
- Create: `Sources/DofusSwitch/MenuBar/HotkeyRecorderField.swift`

Lightweight AppKit view that captures a key event when focused, bridged into SwiftUI via `NSViewRepresentable`.

- [ ] **Step 1: Write implementation**

```swift
// Sources/DofusSwitch/MenuBar/HotkeyRecorderField.swift
import AppKit
import SwiftUI
import DofusSwitchCore

struct HotkeyRecorderField: NSViewRepresentable {
    @Binding var binding: HotkeyBinding
    var label: String

    func makeNSView(context: Context) -> RecorderNSView {
        let view = RecorderNSView()
        view.onCapture = { keyCode, flagsRaw in
            self.binding = HotkeyBinding(
                keyCode: UInt32(keyCode),
                carbonModifiers: HotkeyBinding.carbonModifiers(fromNSEventFlagsRaw: flagsRaw)
            )
        }
        return view
    }

    func updateNSView(_ nsView: RecorderNSView, context: Context) {
        nsView.label = label
        nsView.binding = binding
        nsView.needsDisplay = true
    }
}

final class RecorderNSView: NSView {
    var label: String = ""
    var binding: HotkeyBinding = .defaultNext
    var onCapture: ((UInt16, UInt) -> Void)?

    private var capturing = false

    override var acceptsFirstResponder: Bool { true }
    override var intrinsicContentSize: NSSize { NSSize(width: 180, height: 24) }

    override func mouseDown(with event: NSEvent) {
        capturing = true
        window?.makeFirstResponder(self)
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        guard capturing else { super.keyDown(with: event); return }
        // Require at least one modifier.
        let flags = event.modifierFlags.rawValue
        let hasModifier =
            flags & NSEvent.ModifierFlags.command.rawValue != 0 ||
            flags & NSEvent.ModifierFlags.option.rawValue  != 0 ||
            flags & NSEvent.ModifierFlags.control.rawValue != 0 ||
            flags & NSEvent.ModifierFlags.shift.rawValue   != 0
        guard hasModifier else { NSSound.beep(); return }
        onCapture?(event.keyCode, flags)
        capturing = false
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let bg = capturing ? NSColor.selectedControlColor : NSColor.controlBackgroundColor
        bg.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 4, yRadius: 4).fill()

        let text = capturing ? "Appuyez sur une combinaison…" : prettyPrint(binding)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.labelColor
        ]
        let size = (text as NSString).size(withAttributes: attrs)
        let point = NSPoint(x: (bounds.width - size.width) / 2,
                            y: (bounds.height - size.height) / 2)
        (text as NSString).draw(at: point, withAttributes: attrs)
    }

    private func prettyPrint(_ b: HotkeyBinding) -> String {
        var parts: [String] = []
        if b.carbonModifiers & HotkeyBinding.carbonControl != 0 { parts.append("⌃") }
        if b.carbonModifiers & HotkeyBinding.carbonOption  != 0 { parts.append("⌥") }
        if b.carbonModifiers & HotkeyBinding.carbonShift   != 0 { parts.append("⇧") }
        if b.carbonModifiers & HotkeyBinding.carbonCmd     != 0 { parts.append("⌘") }
        parts.append(keyName(for: b.keyCode))
        return parts.joined()
    }

    private func keyName(for keyCode: UInt32) -> String {
        switch keyCode {
        case 0x7C: return "→"
        case 0x7B: return "←"
        case 0x7E: return "↑"
        case 0x7D: return "↓"
        default: return "key(\(keyCode))"
        }
    }
}
```

- [ ] **Step 2: Build**

Run: `cd /Users/jbaubree/Projets/DofusSwitch && xcodegen generate && xcodebuild -scheme DofusSwitch build 2>&1 | tail -20`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add Sources/DofusSwitch/MenuBar/HotkeyRecorderField.swift
git commit -m "feat(ui): add HotkeyRecorderField (NSView bridged to SwiftUI)"
```

---

## Task 13: SettingsView

**Files:**
- Create: `Sources/DofusSwitch/UI/SettingsView.swift`

- [ ] **Step 1: Write implementation**

```swift
// Sources/DofusSwitch/UI/SettingsView.swift
import SwiftUI
import DofusSwitchCore

struct SettingsView: View {
    @Binding var nextHotkey: HotkeyBinding
    @Binding var prevHotkey: HotkeyBinding
    @Binding var launchAtLogin: Bool
    var onReset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Raccourcis globaux").font(.headline)

            HStack {
                Text("Fenêtre suivante")
                Spacer()
                HotkeyRecorderField(binding: $nextHotkey, label: "next")
                    .frame(width: 160, height: 24)
            }
            HStack {
                Text("Fenêtre précédente")
                Spacer()
                HotkeyRecorderField(binding: $prevHotkey, label: "prev")
                    .frame(width: 160, height: 24)
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
}
```

- [ ] **Step 2: Build**

Run: `cd /Users/jbaubree/Projets/DofusSwitch && xcodegen generate && xcodebuild -scheme DofusSwitch build 2>&1 | tail -20`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add Sources/DofusSwitch/UI/SettingsView.swift
git commit -m "feat(ui): add SettingsView with hotkey recorders and launch-at-login"
```

---

## Task 14: PopoverRootView

**Files:**
- Create: `Sources/DofusSwitch/UI/PopoverRootView.swift`

Navigation root — toggles between list and settings. Also holds the Quit button in the footer.

- [ ] **Step 1: Write implementation**

```swift
// Sources/DofusSwitch/UI/PopoverRootView.swift
import SwiftUI
import DofusSwitchCore

struct PopoverRootView: View {
    @ObservedObject var store: WindowStore
    @State private var showSettings = false
    @State private var axGranted: Bool = AccessibilityPermission.isTrusted(prompt: false)

    let currentWindowKey: () -> String?
    @Binding var nextHotkey: HotkeyBinding
    @Binding var prevHotkey: HotkeyBinding
    @Binding var launchAtLogin: Bool
    let onReset: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if !axGranted {
                OnboardingView(onRecheck: {
                    axGranted = AccessibilityPermission.isTrusted(prompt: true)
                })
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if showSettings {
                SettingsView(
                    nextHotkey: $nextHotkey,
                    prevHotkey: $prevHotkey,
                    launchAtLogin: $launchAtLogin,
                    onReset: onReset
                )
            } else {
                WindowListView(store: store, currentWindowKey: currentWindowKey())
            }
            Divider()
            footer
        }
        .frame(width: 280, height: 360)
    }

    private var header: some View {
        HStack {
            if showSettings {
                Button(action: { showSettings = false }) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)
                Text("Settings").font(.system(size: 13, weight: .semibold))
            } else {
                Text("Dofus windows").font(.system(size: 13, weight: .semibold))
            }
            Spacer()
            Button(action: { showSettings.toggle() }) {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button(action: onQuit) {
                Label("Quit", systemImage: "power")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
```

- [ ] **Step 2: Build**

Run: `cd /Users/jbaubree/Projets/DofusSwitch && xcodegen generate && xcodebuild -scheme DofusSwitch build 2>&1 | tail -20`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add Sources/DofusSwitch/UI/PopoverRootView.swift
git commit -m "feat(ui): add PopoverRootView with list/settings/onboarding routing"
```

---

## Task 15: MenuBarController

**Files:**
- Create: `Sources/DofusSwitch/MenuBar/MenuBarController.swift`

Owns `NSStatusItem` and the detached `NSPopover`.

- [ ] **Step 1: Write implementation**

```swift
// Sources/DofusSwitch/MenuBar/MenuBarController.swift
import AppKit
import SwiftUI

final class MenuBarController {
    private let statusItem: NSStatusItem
    private let popover: NSPopover

    init(rootView: AnyView) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 280, height: 360)
        popover.contentViewController = NSHostingController(rootView: rootView)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "square.grid.3x1.below.line.grid.1x2",
                                   accessibilityDescription: "DofusSwitch")
            button.target = self
            button.action = #selector(togglePopover(_:))
        }
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
```

- [ ] **Step 2: Build**

Run: `cd /Users/jbaubree/Projets/DofusSwitch && xcodegen generate && xcodebuild -scheme DofusSwitch build 2>&1 | tail -20`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add Sources/DofusSwitch/MenuBar/MenuBarController.swift
git commit -m "feat(menubar): add MenuBarController owning NSStatusItem + NSPopover"
```

---

## Task 16: Wire everything in AppDelegate

**Files:**
- Modify: `Sources/DofusSwitch/AppDelegate.swift`

Instantiate all services, build the SwiftUI root, give it to the menu bar controller. React to hotkey events via `CycleController` + `FocusService`.

- [ ] **Step 1: Replace `AppDelegate.swift`**

```swift
// Sources/DofusSwitch/AppDelegate.swift
import AppKit
import SwiftUI
import DofusSwitchCore

final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {

    private let preferencesStore = PreferencesStore()
    private lazy var windowStore = WindowStore(preferencesStore: preferencesStore)
    private let cycleController = CycleController()
    private let focusService = FocusService()
    private let hotkeyManager = HotkeyManager()
    private let detector = WindowDetector()
    private let launchAtLogin = LaunchAtLoginService()

    private var prefs: Preferences = PreferencesStore().load()
    private var menuBar: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Prompt for Accessibility on first launch (non-blocking).
        _ = AccessibilityPermission.isTrusted(prompt: true)

        // Detector → store
        detector.onUpdate = { [weak self] windows in
            self?.windowStore.update(detected: windows)
        }
        detector.scanNow()

        // Hotkeys
        hotkeyManager.onHotkey = { [weak self] id in
            guard let self else { return }
            let target: TrackedWindow?
            switch id {
            case .next: target = self.cycleController.next(in: self.windowStore.visibleWindows)
            case .prev: target = self.cycleController.prev(in: self.windowStore.visibleWindows)
            }
            if let t = target { self.focusService.focus(t) }
        }
        hotkeyManager.rebind(next: prefs.nextHotkey, prev: prefs.prevHotkey)

        // Menu bar
        let root = PopoverRootView(
            store: windowStore,
            currentWindowKey: { [weak self] in
                guard let self else { return nil }
                return self.cycleController.currentIndex(in: self.windowStore.visibleWindows)
                    .flatMap { self.windowStore.visibleWindows[$0].normalizedKey }
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
            onReset: { [weak self] in self?.resetToDefaults() },
            onQuit: { NSApp.terminate(nil) }
        )
        menuBar = MenuBarController(rootView: AnyView(root))
    }

    // MARK: - Preference writes

    private func updateNextHotkey(_ b: HotkeyBinding) {
        prefs.nextHotkey = b
        preferencesStore.save(prefs)
        hotkeyManager.rebind(next: prefs.nextHotkey, prev: prefs.prevHotkey)
    }

    private func updatePrevHotkey(_ b: HotkeyBinding) {
        prefs.prevHotkey = b
        preferencesStore.save(prefs)
        hotkeyManager.rebind(next: prefs.nextHotkey, prev: prefs.prevHotkey)
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        prefs.launchAtLogin = enabled
        preferencesStore.save(prefs)
        launchAtLogin.set(enabled: enabled)
    }

    private func resetToDefaults() {
        prefs = .defaults
        preferencesStore.save(prefs)
        hotkeyManager.rebind(next: prefs.nextHotkey, prev: prefs.prevHotkey)
        launchAtLogin.set(enabled: prefs.launchAtLogin)
    }
}
```

- [ ] **Step 2: Generate + build**

Run: `cd /Users/jbaubree/Projets/DofusSwitch && xcodegen generate && xcodebuild -scheme DofusSwitch build 2>&1 | tail -20`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add Sources/DofusSwitch/AppDelegate.swift
git commit -m "feat: wire detector, hotkeys, cycle, focus, menu bar in AppDelegate"
```

---

## Task 17: Run and smoke-test, then write README

**Files:**
- Create: `README.md`

- [ ] **Step 1: Run the app**

Run: `cd /Users/jbaubree/Projets/DofusSwitch && xcodebuild -scheme DofusSwitch -configuration Debug build 2>&1 | tail -5 && open ~/Library/Developer/Xcode/DerivedData/DofusSwitch-*/Build/Products/Debug/DofusSwitch.app`
Expected: a menu bar icon appears; no Dock icon.

- [ ] **Step 2: Grant Accessibility if prompted**

Confirm System Settings → Privacy & Security → Accessibility → DofusSwitch is enabled. Click "Revérifier" in the popover and verify it switches to the window list screen.

- [ ] **Step 3: Smoke test**

With at least 2 Dofus Unity windows open:
1. Click menu bar icon → both windows are listed with their titles.
2. Press `⌃⌥→` → focus moves to the "next" window.
3. Press `⌃⌥→` again → focus moves to the following window (or wraps).
4. Press `⌃⌥←` → focus moves back.
5. Drag-and-drop a row in the popover → order changes.
6. Press `⌃⌥→` → confirms the new order is used.
7. Quit DofusSwitch, re-launch → list restores same order.
8. Open settings in popover → change the next hotkey to something else → close popover → verify new hotkey works and old one does not.
9. Close a Dofus window → disappears from the popover within ≤2s.

If any step fails, debug before continuing. The two most likely failure modes:
- Bundle id mismatch → nothing detected. Fix: adjust `dofusBundleId` in `WindowDetector.swift`.
- Title does not contain the character name → persisted order shuffles between launches. Fix: documented known risk, accept.

- [ ] **Step 4: Write `README.md`**

```markdown
# DofusSwitch

Minimalist macOS menu-bar app to cycle focus between Dofus Unity windows via global hotkeys.

## Features

- Auto-detect running Dofus Unity instances
- Two global hotkeys: next / previous window (defaults: `⌃⌥→` / `⌃⌥←`)
- Reorderable list in a menu-bar popover (drag-and-drop)
- Launch at login
- Zero network, zero telemetry, no screen recording required

## Requirements

- macOS 13 (Ventura) or later
- Xcode 15+ and `xcodegen` to build (`brew install xcodegen`)
- Accessibility permission (granted at first launch)

## Build & run

```bash
xcodegen generate
xcodebuild -scheme DofusSwitch -configuration Debug build
open ~/Library/Developer/Xcode/DerivedData/DofusSwitch-*/Build/Products/Debug/DofusSwitch.app
```

## Smoke test

1. Launch at least 2 Dofus Unity clients.
2. Click the menu-bar icon → both appear in the list.
3. `⌃⌥→` cycles forward, `⌃⌥←` cycles backward.
4. Drag a row to reorder.
5. Close an instance → disappears from the list within ~2 seconds.

## Known limitations

- Dofus Unity only. No Rétro, no Experimental.
- Persistence of order uses the window title as key. If Dofus does not expose the character name in its window title, the order will not survive relaunches.
- Ad-hoc signed. First launch requires right-click → Open to bypass Gatekeeper.

## Non-goals

- No input broadcasting (forbidden by Ankama).
- No automation of gameplay.
- No reading of game memory.
```

- [ ] **Step 5: Commit**

```bash
git add README.md
git commit -m "docs: add README with build instructions and smoke test"
```

---

## Self-review notes

**Spec coverage check:**
- F1 (detection) → Task 7 ✓
- F2 (next hotkey) → Tasks 2, 5, 6, 16 ✓
- F3 (previous hotkey) → Tasks 2, 5, 6, 16 ✓
- F4 (menu bar + popover) → Tasks 11, 14, 15 ✓
- F5 (drag-and-drop reorder) → Tasks 4, 11 ✓
- F6 (configurable hotkeys) → Tasks 12, 13, 16 ✓
- F7 (launch at login) → Tasks 9, 16 ✓
- F8 (persistence) → Tasks 3, 4, 16 ✓
- 7 components from spec section 3 → one task each ✓
- Permission handling (spec §9) → Task 10 ✓
- Testing (spec §10) → Tasks 1–5 ✓
- Project structure (spec §11) → Task 0 ✓

**Deviations from spec:**
- Spec section 11 showed `.xcodeproj` as a committed artifact; plan generates it via XcodeGen instead and gitignores it. Rationale: the generated project is deterministic and the `.xcodeproj` XML causes merge churn. Added to .gitignore in Task 0.
- Spec section 11 listed `PreferencesStore` implicitly inside `Preferences.swift`; plan splits into two files for clarity.
- Spec file listed `WindowDetector.swift` under `Core/`; plan places it under `DofusSwitch/Services/` because it directly uses AX/NSWorkspace which are side-effectful and not core-testable.

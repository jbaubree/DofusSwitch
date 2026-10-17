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

## First-run bundle ID discovery

The app assumes Dofus Unity's bundle identifier is `com.ankama.dofus`. If
the window list stays empty while a Dofus Unity client is running:

```bash
osascript -e 'tell application "System Events" to get bundle identifier of every process whose name contains "Dofus"'
```

Copy the printed bundle id and update the constant in
`Sources/DofusSwitch/Services/WindowDetector.swift` (`dofusBundleId`),
then rebuild.

## Known limitations

- Dofus Unity only. No Rétro, no Experimental.
- Persistence of order uses the window title as key. If Dofus does not expose the character name in its window title, the order will not survive relaunches.
- Ad-hoc signed. First launch requires right-click → Open to bypass Gatekeeper.

## Non-goals

- No input broadcasting (forbidden by Ankama).
- No automation of gameplay.
- No reading of game memory.

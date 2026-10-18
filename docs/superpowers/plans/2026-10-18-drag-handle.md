# Drag Handle Visibility — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the existing drag-to-reorder feature in `WindowListView` discoverable by adding a grab-handle icon on the left of each row.

**Architecture:** Single-file, purely visual change. Inserts a `line.3.horizontal` SF Symbol as the first element of the row's `HStack`, teinted `.tertiary` at 16×16 pt. The native SwiftUI `List.onMove` drag preview on macOS provides the elevation effect — no custom shadow/scale code. The icon is purely visual (no `.onDrag` attached): on macOS, `List + .onMove` already captures drag on the full row.

**Tech Stack:** SwiftUI (macOS 13+), SF Symbols. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-10-18-drag-handle-design.md`

---

### Task 1: Add drag handle icon to each row

**Files:**
- Modify: `Sources/DofusSwitch/UI/WindowListView.swift:24-32` (HStack inside the ForEach)

- [ ] **Step 1: Confirm current state of the HStack**

Read `Sources/DofusSwitch/UI/WindowListView.swift` (offset 22, limit 17).

Expected content around that region (verbatim):

```swift
            List {
                ForEach(store.visibleWindows) { window in
                    HStack(spacing: 8) {
                        iconFor(pid: window.pid)
                        Text(window.displayTitle).lineLimit(1)
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
```

If the output differs (file already edited, line numbers moved), STOP and re-read the file to locate the HStack before continuing — do not blindly apply the Edit below.

- [ ] **Step 2: Insert the drag handle as the first HStack child**

Use the `Edit` tool on `Sources/DofusSwitch/UI/WindowListView.swift`.

- `old_string`:
```swift
                    HStack(spacing: 8) {
                        iconFor(pid: window.pid)
```

- `new_string`:
```swift
                    HStack(spacing: 8) {
                        Image(systemName: "line.3.horizontal")
                            .foregroundStyle(.tertiary)
                            .frame(width: 16, height: 16)
                        iconFor(pid: window.pid)
```

Notes:
- `line.3.horizontal` is a standard SF Symbol (3 stacked horizontal lines, a.k.a. "hamburger") available since macOS 11 — safe for the project's `MACOSX_DEPLOYMENT_TARGET: "13.0"` (see `project.yml:5`).
- `.foregroundStyle(.tertiary)` keeps the handle discreet so it doesn't compete with the app icon or the title.
- `.frame(width: 16, height: 16)` matches the size of the app icon rendered by `iconFor(pid:)` at `WindowListView.swift:46-48`, keeping row height stable.
- Do **not** attach `.onDrag` to this Image. On macOS, `List + .onMove` already captures drag on the full row; a dedicated `.onDrag` would conflict with `.onMove` and break reordering.

- [ ] **Step 3: Regenerate the Xcode project and build**

The project uses `xcodegen` (see `README.md:18`). Running `xcodegen generate` is idempotent — safe to run even if nothing structural changed.

Run:
```bash
xcodegen generate && xcodebuild -scheme DofusSwitch -configuration Debug build
```

Expected: build succeeds. Last line contains `** BUILD SUCCEEDED **`.

If the build fails:
- Compile error on the new `Image` lines → re-check the Edit; the file must still parse as Swift.
- Project-generation error from `xcodegen` → unrelated to this change; stop and report.

- [ ] **Step 4: Run the existing unit tests (sanity check)**

The change is visual-only but we still run the suite to make sure nothing accidentally regressed.

Run:
```bash
xcodebuild -scheme DofusSwitch -configuration Debug test -destination 'platform=macOS'
```

Expected: `Test Suite 'All tests' passed`. The 5 existing test classes under `Tests/DofusSwitchCoreTests/` (including `WindowStoreTests` with 6 tests) should all pass. No new failures.

If a test fails: STOP. Do not commit. The change is visual-only so a logic test failing means the environment or an unrelated issue — report to the user.

- [ ] **Step 5: Manual visual check (user-driven, not blocking)**

Automated verification does not cover appearance. Launch the app and confirm by eye that:
1. Each row shows the hamburger handle on the far left, then the Dofus icon, then the character name.
2. The handle is visibly dimmer than the title text (because `.tertiary`).
3. Dragging a row still reorders the list (regression check on `.onMove`).
4. During a drag, macOS shows its native translucent preview with a soft shadow (the "elevation" effect).

Launch command (from `README.md:26`):
```bash
open ~/Library/Developer/Xcode/DerivedData/DofusSwitch-*/Build/Products/Debug/DofusSwitch.app
```

If the macOS accessibility permission has been reset by the rebuild, follow the `tccutil` recipe in `README.md:38`.

Note for the agent: this step is a user responsibility. If running autonomously without a human to look at the screen, report "manual visual check pending" and proceed to commit — the automated gates (build + tests) have already passed.

- [ ] **Step 6: Commit**

```bash
git add Sources/DofusSwitch/UI/WindowListView.swift
git commit -m "$(cat <<'EOF'
feat(ui): add drag handle icon to window list rows

Adds a tertiary-tinted line.3.horizontal SF Symbol as the first element
of each row in WindowListView to signal that rows are draggable.
Reordering itself was already functional via List+.onMove; this change
only adds the affordance. Native macOS drag preview provides the
elevation effect.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

Expected: commit created on `main`. No files other than `WindowListView.swift` in the diff — `xcodegen generate` in Step 3 may touch `DofusSwitch.xcodeproj/project.pbxproj`; if that happens because the pbxproj is checked in, it's acceptable to include it in the same commit (adjust `git add` accordingly). Confirm with `git diff --cached --stat` before committing.

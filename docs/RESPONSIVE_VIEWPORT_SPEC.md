# Responsive Viewport & Fullscreen Fit — Spec Sheet

Status: **Phase 1 implemented** · 2026-11-05 · scope: the whole V3 shell and Table

This is the contract for making the UI fit the screen in **windowed and
fullscreen** modes at every supported resolution, aspect ratio, and display
scale. It is written to fix the current fullscreen overflow and to prevent the
same class of bug when new rooms, overlays, and table modes are added.

The rule is simple:

> **No visible control may extend outside the safe viewport. Fullscreen is a
> window mode, not a second layout.**

---

## 1. What is going wrong today

The app currently mixes three coordinate systems:

| Surface | Coordinate space | Scale source |
|---|---|---|
| Shell rooms | `canvas_items` logical canvas | `content_scale_size = 1440×900` |
| Table | native window pixels | `DuelBoardStage.size` |
| Overlays | whichever mode is active when opened | `get_viewport_rect()` |

The result is that a layout can be correct in one mode and wrong in another.
The current code also has no fullscreen state at all.

### 1.1 Root-cause inventory

| # | Risk | Where | Why it breaks |
|---|---|---|---|
| 1 | Entering a shell room resets the window to `1440×900` | `src/presentation/app.gd:114-115` | In fullscreen this fights the display mode and can leave the content larger/smaller than the screen. It also discards the user's windowed size. |
| 2 | Fullscreen is not tracked | no `MODE_FULLSCREEN` handling in `src/` | The app cannot distinguish “fill the display” from “set the window to 1440×900”, so every screen change is a resize opportunity. |
| 3 | Content scale changes per screen | `app.gd:150-159` | Shell uses a 1440×900 canvas, the table disables content scale. A screen switch changes the meaning of every `Control` coordinate. |
| 4 | The Table uses raw stage size with no safe rect | `src/presentation/table/duel_board_stage.gd` | The score rail, ribbon, board, hand shelf, and dock are packed against the raw edges. There is no notch/menu-bar inset and no “fit below minimum” rule. |
| 5 | Fixed-size overlays | drawer `420` (`table_screen.gd:197`), pile `860×600` (`1620`), zoom `1024×720` (`zoom_overlay.gd:43`), confirm `520×220`, result `760` | They have minimum sizes but no “shrink then scroll” policy. A small fullscreen or a large text scale can push them past the edge. |
| 6 | Shell assumes a fixed design width | `project.godot` `viewport_width/height=1440×900`, `aspect=expand`; `show_screen` reset | Extra width/height is allowed to stretch content instead of being given to fluid rails, so fullscreen aspect changes can move controls off-screen. |
| 7 | The audit is windowed-only | `tests/layout_audit.gd`, `tools/run_layout_audit.sh` | There is no fullscreen run, no aspect-ratio matrix, no HiDPI run, and no safe-area check. |
| 8 | No fit helper / no debug overlay | — | There is no single place that says whether a control is inside the safe rect, so regressions are found by looking at screenshots. |

### 1.2 Current evidence

Local fullscreen captures:

- `screenshots/full_library.png`, `full_gate.png`, `full_deck.png`,
  `full_bench.png`, `full_pack.png` — shell at 2560×1600 fullscreen.
- `screenshots/table_focus.png` — table at 2560×1600 fullscreen.
- `screenshots/table_x2_*.png` — table at windowed sizes from 960×720 to
  2560×1440.

The captures show why the fit contract matters: the table is packed edge to
edge at 2560×1600 (2px side margin), while the shell uses a fixed 1440×900
canvas. Both can look correct in one mode and drift in another. The exact
failing display/resolution must be captured in Phase 0 with the debug overlay
(section 9.2) before code is changed.

---

## 2. Goals and non-goals

### Goals

1. Every room, overlay, HUD, drawer, and table surface stays inside the safe
   viewport at every supported size.
2. Fullscreen entry/exit never changes layout logic; it only changes available
   space.
3. The Table keeps its current visual language: 5:7 cards, B1/B3 backrow,
   30% hand shelf, 150% chrome.
4. Text, buttons, and cards remain readable and clickable; no clipped labels or
   half-visible hit targets.
5. The same contract works for 4:3, 16:10, 16:9, 21:9, square, Retina/HiDPI,
   and multi-monitor setups.
6. New screens and overlays cannot ship without passing the matrix.

### Non-goals

- Redesigning the visual language or the card grammar.
- Mobile/touch layout (future; the same safe-rect primitives should survive).
- Replacing the table with a side-hand layout. X2 Spring Shelf remains.
- Achieving edge-to-edge content in every room immediately. Safe letterboxing
  is allowed for the shell in the first pass; fluid rails are the follow-up.

---

## 3. Normative fit contract

These rules are testable and apply everywhere.

### 3.1 Definitions

- **Viewport**: the drawable content area of the window, in logical pixels.
- **Safe rect**: the viewport minus OS/display insets (notch, menu bar,
  rounded corners, cutout) and minus the app's outer margin.
- **Design minimum**: the smallest size at which a screen is still usable
  without scaling text below 10px or hit targets below 44px.
- **Fullscreen**: `Window.MODE_FULLSCREEN` or
  `Window.MODE_EXCLUSIVE_FULLSCREEN`. It is a mode, not a size.
- **Fit scale**: a uniform scale applied to a fixed-size surface so it fits the
  safe rect. It never changes card aspect ratio.
- **Chrome**: the non-card UI: score rail, dock, buttons, labels, tabs,
  drawer, ribbon.

### 3.2 The contract

1. **Containment.** For every visible `Control` that is not intentionally
   clipped (a hand shelf, scroll view, or clipped card strip), its global rect
   must be inside the safe rect.
2. **No text clipping.** A label must not be clipped by its own rect, its
   parent, or the safe rect. Long text wraps, shrinks to the declared minimum,
   or scrolls.
3. **No orphaned hit targets.** A clickable control must be fully inside the
   safe rect. Partially visible controls are not allowed.
4. **No forced size.** Calling `show_screen`, entering a room, or changing
   fullscreen must not call `window_set_size` unless the app is in windowed
   mode and the call is the explicit “reset to shell size” action.
5. **No layout dependence on physical pixels.** Breakpoints use the logical
   viewport/safe rect. Display scale is applied once in the metrics layer.
6. **Fullscreen is lossless.** Entering fullscreen preserves the logical layout
   mode; exiting restores the previous windowed mode, size, and position.
7. **Fit before overflow.** When a fixed surface cannot fit, it shrinks to the
   safe rect, then scrolls internally. It never extends past the edge.
8. **Clipping is explicit.** Intentional clipping is declared with
   `clip_contents` and documented in the screen's layout spec. The audit skips
   those subtrees only.
9. **Every screen declares a minimum.** Below that minimum the app uses a
   fit-scale/letterbox fallback, not cropping.
10. **One audit.** The same geometry audit runs in windowed and fullscreen.

### 3.3 Fit equations

For an overlay or fixed panel:

```text
inner  = safe_rect.grow(-margin)
scale  = min(1.0, inner.size.x / design.size.x, inner.size.y / design.size.y)
size   = design.size * scale
origin = inner.position + (inner.size - size) * 0.5
```

If `size.y` would be below the usable minimum, keep the width fit and make the
body scroll instead of shrinking the header/footer below 44px.

For the Table (B1):

```text
available = safe_rect
c = floor(min(
    (available.h - score - dock - shelf - gaps - pad2) / 3.1,
    (available.w - side_pad2) / 6.0
))
board_w = 6c + 48
```

For B3:

```text
c = floor(min(
    (available.h - score - dock - shelf - ribbon - gaps - pad2) / 3.1,
    (available.w - side_pad2 - 208) / 3.0
))
board_w = 3c + 208
```

The constants live in `Tokens`/`DuelBoardStage`, not in the spec. The important
part is that `available` is the **safe rect**, not `stage.size`, and that `c`
has a declared floor and a declared fallback.

### 3.4 Table floor

Current supported window minimum: **960×720** logical.

- At or above the floor: B1 at width ≥1280, otherwise B3.
- Below the floor: apply a uniform fit-scale to the entire table subtree so the
  board, score, shelf, and dock remain visible. Do not clip; do not let cards
  overlap the dock.
- Recommended floor for future content: `960×720` table, `1280×720` shell.
  If the display cannot provide it, the fit-scale path is mandatory.

---

## 4. Target architecture

### 4.1 One viewport frame

```
App
└─ ViewportFrame                 ← owns mode, safe rect, scale, DPR
   ├─ safe_rect
   ├─ debug overlay (F10)
   └─ ScreenHost
      └─ ScreenLayoutSpec
         ├─ shell content
         └─ overlays (FitPanel)
```

`ViewportFrame` is the only place that reads:

- `get_viewport_rect().size`
- `DisplayServer.window_get_mode()`
- `DisplayServer.screen_get_size()` / `screen_get_usable_rect()`
- `DisplayServer.screen_get_scale()`
- (`DisplayServer.get_display_safe_area()` when the platform supports it)

Everything else consumes `safe_rect`, `viewport_size`, `mode`, and `dpr` from
this layer.

### 4.2 Window mode controller

Add a small `WindowMode` service with these responsibilities:

```text
enter_fullscreen()
  if already fullscreen: return
  saved_mode = current mode
  saved_rect = current position + size
  saved_min  = min_size
  set mode = FULLSCREEN
  do not set size
  apply viewport frame
  emit mode_changed

exit_fullscreen()
  set mode = WINDOWED
  restore saved size/position
  restore min_size
  apply viewport frame
```

Rules:

- `show_screen` must not call `window_set_size` while `is_fullscreen`.
- Windowed shell reset is a separate call:
  `reset_shell_window_windowed()` and it is a no-op in fullscreen.
- `window.min_size` is applied only in windowed mode.
- A screen/monitor change or DPR change re-runs `apply viewport frame`, then
  relayouts once. It must not change the layout mode by itself.

### 4.3 Screen layout spec

Each screen owns a small spec (resource or constants):

```text
design_min       : Vector2i      # e.g. 1280×720 for shell, 960×720 for table
design_reference : Vector2i      # e.g. 1440×900
overflow         : SHRINK | SCROLL | STACK
shell_mode       : CONTAIN | FLUID
safe_insets      : Vector4       # left/top/right/bottom
max_content      : Vector2       # optional cap for huge displays
```

New screens must declare one. Code review rejects a new screen with absolute
positions or a minimum size larger than the available safe rect.

### 4.4 FitPanel / FitOverlay

All overlays use a shared fit wrapper:

- `max_size = safe_rect.size - 2*margin`
- shrink the panel to fit; keep header/footer at ≥44px
- make the body a `ScrollContainer` if content still does not fit
- center in the safe rect
- never use a min size larger than `max_size`
- close/cancel controls stay inside the safe rect

Applies to:

- Table drawer (`420` now)
- Pile overlay (`860×600`)
- Zoom overlay (`1024×720` / `920×660`)
- Confirm dialog (`520×220`)
- Result ceremony (`760` panel)
- Context menu (`264`, already partially responsive)
- Any future modal/dialog/help surface

---

## 5. Per-surface policy

### 5.1 Shell rooms

First pass (fit now):

- Keep the 1440×900 design canvas.
- Use a **contain** policy: scale the design canvas to the safe rect and center
  it. Extra space becomes background/letterbox, not stretched controls.
- Keep the top nav at 52px logical; if the safe width cannot hold brand + nav +
  resource chips, switch to the compact top nav (short brand, overflow menu).
- Shell minimum: `1280×720`; below it, fit-scale and preserve hit targets.
- Never let the windowed shell reset run in fullscreen.

Future (fluid):

- Replace the fixed 1440 canvas with a fluid rail system:
  - `wide` ≥1600: three columns (index / shelf / desk)
  - `standard` 1280–1599: two columns, desk collapsible
  - `compact` <1280: one column, desk becomes a drawer
- Extra width goes to the shelf grid and desk, not to stretching labels.
- Extra height goes to scroll areas, not to fixed panels.

### 5.2 Table

- Uses native pixels (content scale disabled) so the 5:7 card can scale.
- Uses `safe_rect` for all metrics; no raw `size` left after Phase 3.
- B1 at safe width ≥1280; B3 below. Both must be checked against safe height.
- Card floor 120; if the computed card is below the floor, fit-scale the table
  subtree uniformly. No card is ever squashed.
- Score rail: fully inside safe top; the menu button is anchored to the safe
  right, not the board's right.
- Backrow: B1 full public face-up cards; set cards face-down. B3 ribbon uses
  the full effect text and collapses to `+N MORE` only when it cannot fit two
  lines.
- Hand shelf: 30% of card width, clipped intentionally. The shelf, deck strip,
  and dock must sit above the safe bottom. A lifted/pinned card may overlay the
  board, but its full rect must stay inside the safe viewport; the lift is
  clamped if it would reach the score rail.
- Drawer: width `min(420, safe.w * 0.40)`; full height inside safe rect. It is
  an overlay, so covering the board is allowed; extending past the screen is
  not.
- Pile/zoom/confirm: use `FitPanel`.

### 5.3 Overlays and modal surfaces

- All use `FitPanel`.
- All body content scrolls when the fitted panel is too short.
- At most one modal layer; no nested fixed overlays that can stack past the
  edge.
- Escape/close is always visible and hit-testable.
- Text zoom/reduced motion does not change the fit contract.

### 5.4 Toasts and cursor/tooltip layers

- Anchor to the safe rect, not the raw viewport.
- Long toasts wrap or ellipsize; they never push a button off-screen.
- Context menus clamp both axes and flip above/below the anchor.

---

## 6. Fullscreen lifecycle

```
WINDOWED  --enter_fullscreen-->  FULLSCREEN
   ^                                  |
   └---------- exit ------------------┘
```

### On enter

1. Record `mode`, `position`, `size`, `min_size`.
2. Set fullscreen mode.
3. Wait for the OS mode change (`NOTIFICATION_WM_SIZE_CHANGED` or a
   one-frame defer).
4. Recompute safe rect/DPR.
5. Relayout in place. Do not recreate the screen.

### On exit

1. Set mode back to the saved mode.
2. Restore size and position.
3. Restore `min_size`.
4. Recompute safe rect/DPR.
5. Relayout. Do not teleport to a corner.

### On monitor/DPR change

- Reuse the same screen instance.
- Recompute safe rect.
- Re-run the table's card-size calculation and `apply_rest` once.
- Do not reset the window size, do not reset fullscreen, do not lose selection.

### Failure states

- If the requested fullscreen mode is unavailable, fall back to borderless
  fullscreen; if that fails, stay windowed and toast a non-blocking message.
- If the safe rect is degenerate (0/negative), keep the last good layout and
  log once; do not divide by zero.
- If the display reports a scale change mid-frame, defer relayout one frame.

---

## 7. DPI, safe areas, and multi-monitor

- Read DPR from `DisplayServer.screen_get_scale(screen)`.
- All breakpoints and minimums are logical pixels. Physical size is only used
  for the final window/display call.
- Apply DPR **once**. On macOS Retina the window/viewport may already be in
  logical points; on other platforms it may be physical. `ViewportFrame` records
  `window_size`, `viewport_size`, `screen_size`, and `dpr`, and the debug overlay
  shows all four. Never multiply a rect that is already logical by screen scale.
- Chrome scale: `clamp(base_scale * dpr_factor, 1.0, 2.0)` where `base_scale`
  is the room's declared scale (table = 150%). Do not let Retina make 48px
  targets physically tiny.
- Safe insets:
  - windowed: use `screen_get_usable_rect()` to avoid the menu bar/dock.
  - fullscreen: use `screen_get_size()` plus the platform safe-area API when
    present (notch/Dynamic Island, rounded corners).
  - default safe inset: 0; shell/table outer margin: 4 logical px.
- Multi-monitor: the current screen is the one containing the window center;
  fullscreen uses that screen's safe rect. Moving between screens triggers the
  same relayout path.
- Never cache a safe rect across mode changes.

---

## 8. Breakpoints and test matrix

### 8.1 Table modes

| Safe width | Mode | Backrow |
|---|---|---|
| ≥1280 | B1 Front Row | face-up full card; set face-down |
| <1280 | B3 Effect Ribbon | tucked card + 40px ribbon |
| <960 or <720h | Fit-scale | same mode, uniform scale |

Height is always checked first. Width alone never authorizes a layout that
cannot fit vertically.

### 8.2 Acceptance matrix

Each row is tested in **windowed** and **fullscreen**. Each row is tested at
DPR 1.0 and 2.0 (simulated if the display is 1x).

| Window | Aspect | Table | Shell |
|---|---|---|---|
| 800×600 | 4:3 | fit-scale, no crop | fit-scale, no crop |
| 960×720 | 4:3 | B3, floor | compact, fit |
| 1000×1000 | 1:1 | B3 | compact, fit |
| 1024×768 | 4:3 | B3 | compact, fit |
| 1280×720 | 16:9 | B1, floor | compact, fit |
| 1280×1024 | 5:4 | B1 | standard, fit |
| 1366×768 | 16:9 | B1 | standard, fit |
| 1440×900 | 16:10 | B1 | standard, reference |
| 1512×982 | 3:2 | B1 | standard, fit |
| 1600×900 | 16:9 | B1 | wide, fit |
| 1920×1080 | 16:9 | B1 | wide, fit |
| 1920×1200 | 16:10 | B1 | wide, fit |
| 2560×1440 | 16:9 | B1 | wide, fit |
| 2560×1600 | 16:10 | B1 | wide, fit |
| 3440×1440 | 21:9 | B1, centered | wide, fit |
| 3840×2160 | 16:9 | B1, capped card | wide, fit |
| 5120×1440 | 32:9 | B1, centered | wide, fit |

Additional matrix passes:

- Windowed ↔ fullscreen ↔ windowed, 10 cycles, exact window restore.
- Move the window between two displays with different DPR.
- Toggle fullscreen from Library, Gate, Deck, Bench, Pack, Table, and with a
  drawer/pile/zoom/confirm open.
- Resize by dragging the window edge through all breakpoints.
- Reduced motion, 200% text/scale (if supported), and the smallest supported
  window.

### 8.3 Visual pass criteria

- No visible control outside the safe rect.
- No clipped score, dock, hand shelf, ribbon, drawer header, modal footer, or
  close button.
- The table's card stays 5:7; no card is squashed; no lane is hidden.
- The hand shelf shows at least the title strip; hover/focus/click still lift
  and pin.
- The drawer/pile/zoom either fit or scroll; they never run past the safe edge.
- Fullscreen exit restores the windowed rect exactly.

---

## 9. Verification and tooling

### 9.1 Automated geometry audit

Extend `tests/layout_audit.gd`:

- accept `--size=WxH` (already added for windowed)
- accept `--fullscreen` and `--dpr=1|2`
- compute `safe_rect` from the same `ViewportFrame` as the game
- visit every visible `Control`; skip declared clipped subtrees
- fail with screen, node path, rect, safe rect, mode, and DPR
- run the matrix in CI (or a local gate) and store screenshots

The audit must not use `DisplayServer.window_get_size()` for breakpoints; it
uses the same logical metrics as the game.

### 9.2 Debug overlay (F10)

Draw, on top of the current screen:

```text
MODE      windowed | fullscreen | borderless
VIEWPORT  2560 × 1600
SAFE      (0,24) 2560 × 1576
DPR       2.0
SCALE     1.00
SCREEN    Library (compact/wide)
TABLE     B1 · card 418 · shelf 125
OVERFLOW  none | 2 nodes (paths)
```

The overflow list is the fastest way to reproduce a user report. It is
dev-only and hidden in release.

### 9.3 Evidence to attach to the fix

- Fullscreen and windowed screenshots for every matrix row.
- The audit log from the nine current sizes plus fullscreen.
- A recording/gif of the fullscreen toggle with the drawer and a modal open.
- Before/after window restore measurements (position + size).

---

## 10. Rollout plan

### Phase 0 — Reproduce and freeze the contract

- Add the debug overlay and capture the user's failing display/mode.
- Add the safe-rect definition and the fit equations to the codebase.
- Add fullscreen/no-fullscreen to the audit harness.
- **Exit:** the current overflow is reproducible in a test, not just a
  screenshot.

### Phase 1 — Window mode and scale ownership (implemented 2026-11-05)

- [x] Add `WindowMode` and `ViewportFrame`.
- [x] Remove the fullscreen `window_set_size`/`min_size` reset from `show_screen`.
- [x] Make shell rooms contain/fit; keep table native.
- [x] Apply `FitPanel` to the drawer, pile, zoom, confirm, result, and help
  surfaces.
- [x] Add the modal pass to the geometry audit.
- **Exit:** 0 failures at the 15-size windowed matrix and fullscreen; the table
  and modals stay inside the viewport. Fullscreen restore and exact window
  restore are exercised by `fullscreen_toggle` and `table_window_restore`.
  Phase 2 still owns the table's internal safe-rect clamp.

### Phase 2 — Table safe-rect port

- Replace `stage.size` with `safe_rect` in `DuelBoardStage`.
- Clamp B1/B3 card and chrome; add the fit-scale fallback below 960×720.
- Clamp pinned-hand lift to the safe viewport.
- Keep the current B1/B3 and 30% shelf behavior.
- **Exit:** table passes the full matrix, including 960×720, square, 16:10,
  ultrawide, fullscreen, DPR 2.

### Phase 3 — Shell fluid rails (future-proofing)

- Convert Library/Gate/Deck/Bench/Pack to `ScreenLayoutSpec` + fluid rails.
- Remove the fixed 1440 canvas dependence.
- **Exit:** shell fills wide screens without stretch, stacks at compact sizes,
  and never clips.

### Phase 4 — Guardrails

- Add the audit to the release checklist.
- Add a “new screen” template with `ScreenLayoutSpec`.
- Add a code-review checklist item: no raw absolute positions, no new
  `window_set_size` outside `WindowMode`, no min size larger than safe rect.
- Add the matrix to `docs/README.md` and `docs/PLAN.md`.

---

## 11. Definition of done

- [ ] Fullscreen entry/exit never changes layout logic; only available space.
- [ ] No visible control extends outside the safe rect in any matrix row.
- [ ] Window size/position/min-size are restored exactly after fullscreen.
- [ ] Table B1/B3, 30% shelf, pinned lift, and drawer work in fullscreen.
- [ ] Drawer, pile, zoom, confirm, result, and context menu fit or scroll.
- [ ] Shell rooms fit 4:3, 16:10, 16:9, 21:9, and square.
- [ ] DPR 2 / Retina is tested; targets remain ≥44 logical px.
- [ ] The geometry audit runs in windowed and fullscreen and fails CI on
      overflow.
- [ ] README, PLAN, STYLE, and the review status match the implementation.

---

## 12. Rules for future UI

1. Every screen has a `ScreenLayoutSpec`.
2. Every overlay uses `FitPanel`.
3. No control uses the raw window size for a breakpoint; use
   `ViewportFrame.safe_rect` / `Responsive`.
4. No `window_set_size` / `window_set_position` outside `WindowMode`.
5. No new fixed minimum larger than the design minimum without a fit fallback.
6. Intentional clipping is declared, documented, and audit-exempt.
7. New breakpoints are added to the matrix and screenshots.
8. Fullscreen is tested on the same PR as the new surface.
9. A layout bug fix adds a failing audit row before the code fix.
10. The debug overlay stays available in dev builds.

---

## 13. Open decisions

These need a product call before Phase 3; Phase 1 can ship with the recommended
defaults:

| Decision | Recommended default | Alternative |
|---|---|---|
| Shell at non-16:9 | Contain/fit with background bars | Fluid rails (more work) |
| Table card above 4K | Cap at 420 and center | Let it grow to 500+ |
| Safe inset on macOS fullscreen | Use platform safe area + 4px margin | Ignore notch, full bleed |
| Below 960×720 | Uniform fit-scale | Show unsupported resolution |
| Drawer width at compact | `min(420, safe width - 24)` | Full-screen drawer |
| Shell minimum | 1280×720 | 960×720 with fit-scale |

---

## 14. Code touchpoints for the fix

| File | Change |
|---|---|
| `src/presentation/app.gd` | WindowMode + ViewportFrame ownership; no fullscreen resize; single scale policy |
| `project.godot` | Declare base canvas, min sizes, stretch/aspect policy |
| `src/presentation/screens/table_screen.gd` | Safe-rect host, drawer FitPanel, clamp drawer width |
| `src/presentation/table/duel_board_stage.gd` | Safe-rect metrics, card/chrome clamp, fit-scale fallback |
| `src/presentation/table/card_actor.gd` | Clamp pinned lift to safe viewport |
| `src/presentation/overlays/*` | FitPanel / scroll fallback |
| `src/presentation/screens/*` | ScreenLayoutSpec; compact/wide rules |
| `tests/layout_audit.gd` | Fullscreen, DPR, safe-rect geometry audit |
| `tools/run_layout_audit.sh` | Full matrix including fullscreen and DPR |
| `docs/README.md`, `docs/PLAN.md` | Link this spec and track phases |

---

## Appendix A — Minimal “fix now” order

If only the smallest safe change is funded:

1. Stop `show_screen` from resizing in fullscreen.
2. Add `WindowMode` save/restore.
3. Add `safe_rect` and pass it to the table and overlays.
4. Wrap the drawer/pile/zoom/confirm in `FitPanel`.
5. Add the fullscreen row to the audit.

That removes the overflow without changing the visual language. The fluid shell
and the full test matrix can follow without reopening the table layout.

## Appendix B — Terminology

- **B1**: front-row backrow mode at safe width ≥1280; face-up spells/traps are
  full public cards.
- **B3**: ribbon mode below 1280; face-up effects are text in a 40px ribbon.
- **Spring Shelf**: the 30% bottom hand shelf; hover/focus/click lifts the full
  card; click pins.
- **Safe rect**: viewport minus OS/display insets and app margin.
- **Fit-scale**: a uniform scale of a whole subtree so it fits the safe rect.

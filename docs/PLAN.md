# Plan

Current plan of record for the Razeah V3 rework. The rules and content come
from V2; the visual contract is Neon Reliquary; this document decides the order.

## Status

| Item | Status |
|---|---|
| Table direction review | Complete — seven directions in `review/index.html` |
| Chosen table direction | **Neon Reliquary** |
| Pack-opening review | Complete — `review/packs.html` |
| Pack ceremony direction | **Neon Reliquary / Folio Protocol** |
| V3 Godot project | V2 baseline imported; Neon shell and Table rebuilt |
| V2 rules/content | Source of truth, untouched |
| Face-sealed rule | **Enforced in `DuelRules`**; tests cover sealed/open faces and AI |
| Table presentation | **X2 Spring Shelf landed** — fluid 150% table, B1/B3 backrow; QA evidence at 1280–2560 and 960/1000 |
| Scale / corner contract | **Resolved: full-window 150% chrome; B1 ≥1280, B3 below; min 960×720; no forced square** |
| Viewport / fullscreen fit | **Phase 1 landed** — WindowMode, ViewportFrame, FitPanel, fullscreen/modal audit; Phase 2 table safe rect pending |
| Folio ceremony | Not started; review lab approved |

The labs are approved design references. They are not shipping code and are not
imported by Godot. The code-level migration route is
[`BUILD_STRATEGY.md`](BUILD_STRATEGY.md).

## Current evidence — 2026-11-04

- **Domain suite:** 412 passed, 0 failed.
- **Layout audit:** 0 failures at 15 windowed sizes plus fullscreen: 1280×720,
  1440×900, 1800×1125, 1920×1080, 1280×1024, 2560×1440, 1000×1000, 960×960,
  960×720, 1024×768, 1366×768, 1920×1200, 2560×1080, 3440×1440, and
  2560×1600 fullscreen (with modal pass).
- **Seeded 100 duels (Ember starter vs the Damp Warden, skill 55):**
  - before the face-sealed rule: **72 wins / 17 losses / 11 draws**, avg 10.4 turns;
  - after the face-sealed rule: **49 wins / 15 losses / 36 draws**, avg 15.8 turns.
  - The direct-attack pressure valve is gone in this control matchup, so games
    take longer and draws rise. This is a known balance consequence, not a test
    failure. Rebalance only with evidence; the first candidates are AI
    guard-breaking and content removal/penetration, not rolling the rule back.
- **X2 table:** 150% chrome at every window (82px score, 64px dock, 48px
  targets, 12–14px labels); the 5:7 card scales to 167 at 1280×720, 225 at
  1440×900, 283 at 1920×1080, and 399 at 2560×1440. At ≥1280 width the backrow
  is **B1 Front Row**: a face-up spell/trap is a full public card next to its
  monster; set cards stay face-down. Below 1280 the backrow is **B3 Effect
  Ribbon**: a 40px text ribbon lists every face-up effect; the full card stays
  available on click/inspect. The hand is a **30% bottom shelf** (title strip
  only) with hover/focus/click lift and click pin; the deck shows the same strip
  and its count. The table fills the current window (min 960×720) and keeps its
  position; top nav hidden, drawer carries all four doors.
- **Table screenshots:** `screenshots/table_x2_1280x720.png`,
  `table_x2_1440x900.png`, `table_x2_1920x1080.png`, `table_x2_2560x1440.png`,
  `table_x2_1000x1000.png`, `table_x2_960x960.png`, `table_x2_960x720.png`, and
  `table_x2_hand_1440x900.png` (pinned full face).
- **Flex review:** `review/flex.html` compares fixed / fluid bottom / fluid side /
  docked cockpit at 1280–3440; the hybrid recommendation was C in landscape, B in
  square. The live table now uses the fluid full-window budget; the old fixed
  190/1000 note in that lab is historical.
- **Viewport / fullscreen:** `WindowMode` saves and restores the exact
  windowed rect; `ViewportFrame` owns the safe rect/DPR; the shell uses a
  contained 1440×900 canvas; the Table stays native. Drawer, pile, zoom,
  confirm, result, and help surfaces use `FitPanel`. Fullscreen and window
  restore are covered by the visual QA scenarios.
- **Shell/room screenshots:** library, gate, deck, bench, folio at 1440×900.

## Working log

| Date | Step | Evidence | Next |
|---|---|---|---|
| 2026-11-02 | Step 0 — baseline | V2 imported; suite 406/0; seeded 72/17/11, avg 10.4; layout audit pass | Neon tokens and shell |
| 2026-11-02 | Step 1 — Neon foundation | Neon tokens/fonts/theme/backdrop; four-door nav; suite 406/0; layout audit pass; room screenshots | Table refactor |
| 2026-11-02 | Step 2 — Neon Table + face seal | Warden strip, three lanes, player/intent rails, hand fan, dock, face contracts, foreground cues, plates, stable actors; suite 412/0; layout audit pass; seeded 49/15/36, avg 15.8 | Finish Phase 2 acceptance, then Folio |
| 2026-11-02 | Step 3 — surface review | First five scale options rejected; committee split the job into Altar (play), Vigil (watch), Sealbreak (hit), Broadside (full), and recommended the stack; `review/surfaces.html` | User rejected hidden lanes/labels |
| 2026-11-02 | Step 4 — twin mats | Two playmats, all three lanes always visible, no I/II/III, OPEN, CALL, or guard sentence; Twin Mat, Clash Rail, Table Edge, Corner Mat in `review/mats.html` | Pick a mat or family |
| 2026-11-03 | Step 5 — Duel Board lab | Four 900 × 900 variants with one card size per board: Grid 105, Overlap 145, Shelf 120, Mirror 120; `review/duel-board.html` | Overlap picked |
| 2026-11-03 | Step 6 — real card renders | Review labs now use actual `CardComposer` PNGs (2× the L token) via `tools/export_review_cards.gd`; Duel Board card sizes stay uniform per variant; exchange corrected to 900 / KINDLE 200 | Build compact Overlap table |
| 2026-11-03 | Step 7 — Overlap table port | `DuelBoardStage`: two mats, one 145px `O` token for hand/monster/set/deck, tucked spell/trap, score rail with guard pips, phase ticks, target bracket, 960×960 compact window, always-on-top PIN, table drawer; suite 412/0; layout audit 6/6 | Compact manual/Auto QA |
| 2026-11-03 | Step 8 — Overlap lab | Four core tucks + five Side Spine cuts, live view/face/peek controls, spread-on-hover, six upgrades; `review/overlap.html` | Index Tab 44 picked |
| 2026-11-03 | Step 9 — Index Tab port | 44px `CARD_TAB`, 189px lane, 22px lane gap, tab ghost/legal target, stable hover zone, full-card front lift; suite 412/0; layout audit 6/6 | Compact manual/Auto QA |
| 2026-11-03 | Step 10 — readability lab | Actual-size 180/190/200/220 tables + 300px detail lens; 960/1012/1060/1096 windows; fit-to-pane; `review/bigger.html` | Pick a readability budget |
| 2026-11-03 | Step 11 — accessibility lab | 190 focus + 100/125/150/200% chrome; 44–56px targets; 54/68/82/106 score bands; 960 exact at 125, 1000 at 150, 1200 at 200; `review/accessible.html` | 150% chosen; build 150 focus |
| 2026-11-03 | Step 12 — accessibility decision | **150% chosen**: 190 card, 52 tab, 48px targets, 12–14px labels, 82 score, 64 dock, 1000×1000 focus; 8px board slack | Port table-only 150 |
| 2026-11-03 | Step 13 — 150 table port | `A` token 190×266; `CARD_TAB` 52; 150/125 stage metrics; 1000/960 focus window; current-position pinned window; shell restore; top nav hidden; drawer doors; suite 412/0; layout audit 6/6; focus + fallback + drawer screenshots | Table manual/Auto QA at both scales |
| 2026-11-04 | Step 14 — flex lab | Window-filling review: A fixed 190, B fluid bottom (123–294), C fluid side (144–443), D docked cockpit; 960–3440 matrix; hybrid C/B recommendation; `review/flex.html` | Pick flex mode and port |
| 2026-11-04 | Step 15 — one-line side hand lab | S1 side fan (older cards 20%, newest full), S2 side scroll (3 visible, max card), S3 bottom row (all six readable, 123–294); one-column width 4c+226; 960–3440 matrix; `review/side-line.html` | Pick one-line hand and port |
| 2026-11-04 | Step 16 — S3 larger lab | Six personas; S3 209 baseline; X1 wall chrome 245; X2 spring shelf 283; X3 open table 247/354/450; X4 hand index + lens 292; 960–3440 matrix; team pick X2; `review/s3-larger.html` | Pick S3 larger layout and port |
| 2026-11-04 | Step 17 — X2 backrow lab | Set vs face-up rule; B1 front row 283/399; B2 effect tabs; B3 ribbon 270/244; B4 rail 292; 960–3440 matrix; team pick B1 1920+, B4 1440, B3 square; `review/x2-backrow.html` | Pick backrow mode and port |
| 2026-11-04 | Step 18 — X2 port | Spring Shelf 30% hand; B1 full face-up backrow ≥1280; B3 full-effect ribbon below; face-down sets stay secret; dynamic 5:7 card 152–399; 150% chrome; fluid min 960×720; stable hover/focus/click pin; 412/0; layout audit 9/9; size screenshots | Manual/Auto QA and reduced-motion pass |
| 2026-11-04 | Step 19 — viewport fit spec | Fullscreen/windowed fit contract; WindowMode + ViewportFrame; safe rects; FitPanel overlays; Table B1/B3 clamp; 800×600–5120×1440 / windowed-fullscreen / DPR matrix; `docs/RESPONSIVE_VIEWPORT_SPEC.md` | Phase 1: stop fullscreen resets, add safe rect + FitPanel + audit |
| 2026-11-05 | Step 20 — viewport fit Phase 1 | `WindowMode` fullscreen save/restore; `ViewportFrame` safe rect/DPR; shell `KEEP` canvas; `FitPanel` for drawer/pile/zoom/confirm/result/help; fullscreen + modal audit; 15 windowed sizes + fullscreen 0 failures; 412/0; exact window restore verified | Phase 2: table safe-rect clamp and below-min fit-scale |

## Locked decisions

These are not reopened without a written reason.

1. **Neon Reliquary is the table direction.** The full recipe is
   [`STYLE_NEON_RELIQUARY.md`](STYLE_NEON_RELIQUARY.md).
2. **The pack ritual follows the same language.** Its state machine and timings
   are in [`../review/PACK_RITUAL.md`](../review/PACK_RITUAL.md).
3. **Four doors, no more:** Play / Library / Decks / Packs. No submenu bar, no
   fifth noun on the primary nav.
4. **No bitmap art.** No illustrations, portraits, painted backgrounds, or
   imported textures. Procedural glyphs, type, materials, and motion carry the
   character. Fonts and audio are the only binary assets.
5. **Cards are 5:7 at every size.** The six-band anatomy is fixed:
   nameplate → seal → type line → rules → stat plate → footer. Themes change
   material and type, never geometry.
6. **One renderer, one token file.** Seven skins or four rooms must not fork the
   board/card/ceremony components. Theme is data.
7. **The table is ported before the folio.** The table is the core loop; the
   folio reference is already stable and does not block it.
8. **The face is sealed while any enemy monster remains.** A direct face attack
   is illegal if any opponent monster zone is occupied, regardless of which lane
   is open. The guard count is visible as three pips beside the Warden score.
9. **The ceremony never decides a result.** Pack contents are committed before
   the first crack frame. The tell is exact. No reroll, no paid re-open, no fake
   near-miss, no urgency.
10. **Skip is a first-class action.** In the folio, skip lands on the ledger,
    never leaves the pack unseen.
11. **Sound is enhancement, not a dependency.** The game remains legible with
    sound off; reduced motion keeps all information.
12. **The old build stays runnable.** V2 is not modified while V3 is being
    ported; it remains the comparison build and the rules source.
13. **The table is X2 Spring Shelf.** It fills the window it is given at **150%
    chrome**; there is no forced 1000/960 square. The card is always 5:7 and
    scales with the board (167–399px across the supported windows). At width
    **≥1280** the backrow is **B1 Front Row**: a face-up spell/trap is a full
    public card next to its monster, and a set card stays face-down and secret.
    Below 1280 the backrow is **B3 Effect Ribbon**: a 40px ribbon lists every
    face-up effect as text; the card stays tucked and the full face is one
    click/inspect away. The hand is the bottom **30% shelf**: only the title
    strip is visible, and hover, focus, or click lifts the full face; click pins
    it. The deck uses the same strip and carries its count. Chrome is 48px
    targets, 12–14px labels, 82px score, 64px dock; the minimum window is
    960×720; all three lanes stay visible; the window keeps its position.

14. **Fullscreen is a window mode, not a layout.** `WindowMode` owns entry/exit
    and exact restore. `ViewportFrame` owns the safe rect and DPR. No screen may
    call `window_set_size` in fullscreen; every overlay uses `FitPanel`. The
    shell is contained; the table is native and will get its safe-rect clamp in
    Phase 2.

## Target architecture

Keep the V2 layering; replace the presentation.

```text
src/domain/          pure GDScript; rules, duel, deck, craft, economy, packs
src/application/     Content, Session, save, services, query
src/presentation/    Neon tokens, theme, shell, screens, cards, FX, audio
content/             authored YAML; generated data.json
tools/               content build, validation, simulation
review/              static visual labs (ignored by Godot)
docs/                workflow, plan, style contract (ignored by Godot)
```

The domain never imports Godot nodes. The presentation issues commands; it never
changes rules. Every visual value lives in `Tokens`; every card geometry lives
in `CardComposer`.

## Phases

### Phase 0 — Baseline and safety net

**Goal:** make V3 a working Godot project with the V2 rules and tests intact,
with the review/docs invisible to the engine.

Tasks:

1. Copy the V2 project into V3 as the baseline: `project.godot`, `scenes/`,
   `src/`, `content/`, `tests/`, `tools/`, `assets/`, `.gitignore`. Exclude
   `.godot/`, `screenshots/`, `tools/.venv/`, caches.
2. Add `review/.gdignore` and `docs/.gdignore`.
3. Keep the review labs and docs in the repository; they are not resources.
4. Run and record:
   - `tools/run_tests.sh`
   - `tools/run_layout_audit.sh`
   - `tools/.venv/bin/python tools/build_content.py`
   - `tools/.venv/bin/python tools/validate_content.py`
5. Take a baseline build/screenshot of the current table and folio for
   comparison.
6. Record the baseline evidence in this file: test count, failures, wins/losses,
   average turns, layout sizes.

Acceptance:

- [x] The baseline boots and plays end to end.
- [x] The full test suite passes; the count is recorded.
- [x] The layout audit passes at all reference sizes.
- [x] `review/` and `docs/` are not imported by Godot.
- [x] The review labs still open from `file://`.
- [x] No V2 files were modified in the process.

### Phase 1 — Neon foundations

**Goal:** the shell and shared chrome are Neon, and every room can be reached.

Tasks:

1. `Tokens.gd`: add the Neon palette, fonts, spacing, radii, material values,
   animation constants, and rarity/tell colors. Do not delete V2 tokens until
   every screen is migrated.
2. `ThemeBuilder`: Neon controls, focus rings, line edits, scrollbars, tooltips.
3. Four-door shell: Play / Library / Decks / Packs, with the active state and
   keyboard paths. Packs routes to the Folio.
4. Shared chrome: run strip, panels, tabs, section labels, buttons, modals,
   gauges, toast style.
5. Room background: void, grid, scanlines, grain, ambient motes, vignette.
6. Stub the other doors visually; do not build them yet.
7. Add the local font files and license notes if the Neon fonts are not already
   in `assets/fonts`.

Acceptance:

- [x] The four doors are reachable and the active door is obvious.
- [x] 1280 / 1440 / 1920 screenshots of the shell.
- [x] No fifth primary navigation item.
- [x] Keyboard focus visible on every control (shared focus style).
- [ ] Reduced-motion shell: no pulse longer than 100 ms. (Table seal respects it; full pass pending.)
- [x] No card or board file has been forked.
- [x] Baseline tests still pass.

### Phase 2 — The Neon table

**Goal:** replace the Table presentation with the Neon Reliquary board, and
enforce the face-sealed rule.

> Superseded 2026-11-03 by the Overlap Duel Board (Step 7): two mats, one 145px
> token, score rail, and drawer. The strip/rails task list below is the original
> first-port plan, kept as history.

Tasks:

1. Build the board skeleton from `STYLE_NEON_RELIQUARY.md`:
   nav, run strip, Warden strip, three lane columns, left player rail, right
   intent/log rail, hand fan, action dock.
2. Reuse `CardComposer`; make the Neon face a token variant. Keep 5:7 and the
   six bands. Add the dark glass, attribute border, seal grid, rarity dot, and
   stat treatment.
3. Introduce stable actors:
   - one `CardActor` per `DuelCard.uid`
   - `BattleStage` owns rest positions and animations
   - no rebuild on every action; text/log/piles update in place.
4. Entry/exit contract: draw, call, set, play, destroy, banish, discard, return,
   token. The first visible frame is the source; the last is the exit. No
   destination pops.
5. `BattleDirector`: drain `DuelState.events`, sequence beats, enforce hit-stop,
   and expose a skip/fast-forward path.
6. Feedback:
   - staged damage numbers
   - score plate (`STRIKE / 2,600`)
   - card recoil, lane focus, residue (cracks, drained bars, open lanes)
   - hand fan lift, playable ring, legal lane glow
   - intent panel updates and log append (no rebuild)
7. Autoplay:
   - cinematic letterbox, lane spotlight, beat captions
   - 1.2 s max without a visible change
   - pause/stop/speed behavior
   - sound cues; silent fallback
8. Rules:
   - exclude direct face attacks while any enemy monster remains
   - update legal-action generation, AI, and any economy assumptions
   - show the guard count / face-sealed cue as score-rail pips
   - add tests: no face with a guard; face when all clear; AI does not loop;
     seeded duel distribution recorded before/after
9. Settings: motion, sound, speed, reduce-flash, keyboard.
10. Layout audit at 1280 / 1440 / 1920; table breakpoints; the 3×2 mats.

Status 2026-11-04: the Overlap Duel Board replaced the strip/rails composition
(Step 7), then the accessible scale (Step 13), then X2 Spring Shelf (Step 18).
The live table is full-window 150% chrome with B1/B3 backrow, a 30% hand shelf,
hidden top nav, drawer doors, manual call, auto pass, 412 tests, and a nine-size
layout audit. Remaining: the 20-action manual acceptance, reduced-motion pass,
and console sweep. Task 9 (settings) is still open.

Acceptance:

- [x] Board screenshot matches the Neon direction at 1440.
- [x] X2 table renders B1 at 1280–2560 and B3 at 1000/960 with a stable 5:7
      card, a 30% shelf, and public face-up spells/traps.
- [ ] A 20-action manual duel has no actor pop for call/set/play/attack/destroy.
- [x] Every authored action has a movement, number, mark, or log line.
- [ ] The score plate appears on damage in Auto and manual. (Implemented; dedicated capture pending.)
- [ ] Auto plays a full turn as a broadcast and pauses cleanly. (Core loop works; full QA open.)
- [x] The face is not attackable while any guard remains.
- [x] The guard count updates when a lane breaks.
- [ ] 60 fps at 1440 with a legendary-scale effect; reduced motion pass.
- [x] Domain suite + 100 seeded duels pass; results recorded.
- [ ] Keyboard: select card, lane, attack/defend, end phase, inspect.
- [ ] No console errors; sound-off legibility confirmed.

### Phase 3 — Folio ceremony

**Goal:** port the approved pack ritual with stable actors and honest tells.

Tasks:

1. Create `FolioCeremony` as the single owner of timing/input/the state machine.
2. Keep the envelope, fan, cards, flare, and stamps stable; no stage rebuild.
3. Implement:
   - sealed, press, crack, flecks, flap, mouth glow, deal stagger
   - exact tells: pips + ring + label, from the committed card
   - 470 ms pinch-and-turn flip + paper edge + 60 ms hold
   - flare grammar: 120 / 220 / 420 / 900 ms
   - NEW / ×N from the pre-open snapshot + per-pack seen count
   - legendary banner and local bloom; no full-screen flash
   - ledger strip; cards stay clickable
4. Modes: Ritual, Quick, Auto; skip lands on the ledger; Reveal All.
5. Summary: cards, new, mods/reagent, set progress, next action.
6. Sound cues and silent fallback; haptics on mobile only.
7. Reduced motion: 80–100 ms crossfades; static tells; immediate summary.
8. Tests: state machine, exact tell, stamps, skip timing, committed result.

Acceptance:

- [ ] The envelope persists from sealed through the ledger.
- [ ] Cards emerge from the mouth; no first frame at the destination.
- [ ] Skip reaches a readable ledger in ≤150 ms from any reveal state.
- [ ] Every rarity tell matches the committed card; no fake near-miss.
- [ ] The flip is 470 ms ±10 ms in Ritual; Quick ≤2.2 s for five cards.
- [ ] Auto stops at the ledger; any input cancels auto.
- [ ] A legendary flare finishes behind the card; next flip is not blocked.
- [ ] Cards remain inspectable in the summary.
- [ ] Reduced motion keeps all labels/stamps/results.
- [ ] 60 fps at 1440×900 with five cards and one legendary flare.

### Phase 4 — The other three doors

**Goal:** make Library / Decks / Packs real rooms in the same language.

Order:

1. **Library** — visual shelves, filters, search, reading desk, card menu.
2. **Decks** — two-pane workshop, shared filters, drag/click/keyboard, health.
3. **Packs / Press** — satchel, purchase, opening queue; route to the ceremony.

Tasks:

- Reuse the Neon tokens and shared components; no new visual language.
- No illustrations; cards and procedural patterns carry the screen.
- Every screen has a clear primary action and a keyboard path.
- Keep the four-door nav global; never nest another top nav.
- Verify flows: Play → Library → Decks → Packs → Folio → Play.

Acceptance:

- [ ] All four doors are real, reachable, and return correctly.
- [ ] The same card face is used everywhere; no forks.
- [ ] Library/Deck/Pack screens use the same buttons, panels, focus, and toasts.
- [ ] Nav tests; layout audit; 1280 / 1440 / 1920.
- [ ] Existing content/deck/save tests pass.

### Phase 5 — Audio, settings, accessibility, performance

- Audio director with the cue contract; recorded or synthesized one-shots.
- Settings: master/music/SFX, reduced motion, reduced flash, rarity tell,
  haptics, speed.
- Accessibility: focus order, contrast, no colour-only signals, screen-reader
  status for the table/folio, text scale.
- Performance: actor pool, flare pool, no per-frame allocations, 60 fps at
  1440, fast-forward path.
- Localization-ready semantic strings.
- A full visual QA matrix at 1280 / 1440 / 1920 and 390 mobile where relevant.

### Phase 6 — Content and launch

This is the V2 roadmap, not this visual milestone: 80 cards, 3 circuits,
12 Wardens, 3 bosses, shrines, etc. Do not add post-launch scope before the loop
is complete. Reuse the V2 content pipeline and validation.

## Sequence and dependencies

```text
Phase 0  baseline
   ↓
Phase 1  tokens + four-door shell
   ↓
Phase 2  table + face-sealed rules
   ↓
Phase 3  folio ceremony
   ↓
Phase 4  library / decks / press
   ↓
Phase 5  audio, settings, accessibility, performance
   ↓
Phase 6  content and launch
```

- Phase 2 depends on Phase 1 tokens and shell.
- Phase 3 depends on Phase 1 tokens; it can run in parallel with late Phase 2 if
  the Folio owner does not touch table files.
- Phase 4 depends on the shared components from 1–3.
- Phase 5 is continuous but the full matrix lands after Phase 4.
- Phase 6 is content; it must not precede a proven loop.

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| Copying V2 then refactoring leaves two visual systems | Delete each old screen as its Neon replacement lands; no screen may keep two styles. |
| Face-sealed rule changes AI/economy/test balance | Record before/after seeded duels; add explicit rule tests; rebalance only with evidence. |
| Neon is loud; readability suffers | Body text stays Inter; Orbitron only for labels/headings; cyan/magenta only on labels/numbers; test at 1280. |
| FX cost with many cards | Stable actors + pooled FX; no per-frame node creation; performance gate at 1440. |
| Card text unreadable at small sizes | 5:7 tokens + text audit; zoom/inspector is a required path; test card-fit. |
| Lab and game drift | The style guide is the contract; update it in the same change as any token/timing change. |
| Godot imports the static labs | `review/.gdignore` and `docs/.gdignore` in Phase 0. |
| Fonts unavailable/offline | Vendor the licensed fonts in `assets/fonts`; no runtime Google dependency in the game. |
| Scope creep into content | Phase 6; the current cut line is the core loop + four doors. |

## Current cut line

In scope now:

- Phase 0 baseline.
- Phase 1 Neon shell.
- Phase 2 table, face-sealed rule, Auto broadcast.
- Phase 3 folio ceremony.

Not now:

- New mechanics, new starter decks, endless mode, daily sealed, museum, bounties.
- Paid gacha, premium currency, rerolls, urgency mechanics.
- Portraits, painted backgrounds, bitmap textures.

## Immediate next action

1. Choose the mat / family in `review/mats.html` and record
   the pick here. This changes the small-window contract, not the rules.
2. Finish Phase 2 acceptance: a 20-action manual duel, a full Auto turn with
   pause/resume, score-plate capture, reduced motion, and a clean console.
3. Only then start Phase 3: the Folio ceremony state machine and stable actors.
3. Keep the face-sealed rule and its seeded-duel evidence attached to any later
   balance change.

If the order changes (folio before table finish), record the reason here first;
do not silently reorder the phases.

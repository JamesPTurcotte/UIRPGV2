# Razeah Cards — V3

The new home for Razeah. V3 now contains the working Godot baseline, the Neon
Reliquary shell, and the rebuilt Neon Table. The approved review labs are still
here as the visual contract. V2 at `../RazeahCardsV2` remains the source of the
game rules and content.

## Run the game

```bash
godot --path .                 # play
tools/run_tests.sh            # 419 tests
tools/run_layout_audit.sh     # 15 windowed sizes + fullscreen
```

The Table is reachable from **Play**. Library, Decks, and Packs are being ported
room by room into the same shell.

## Open the review

The review is a static site: no build step, no server required.

- Table direction review: [`review/index.html`](review/index.html)
- Chosen direction's pack ritual: [`review/packs.html`](review/packs.html)
- Packs + table UX review (panel, hand, drag, pack formats): [`review/ux.html`](review/ux.html)
- Twin mats review: [`review/mats.html`](review/mats.html)
- Duel Board variations (one card size; Overlap chosen): [`review/duel-board.html`](review/duel-board.html)
- Overlap examples and upgrades: [`review/overlap.html`](review/overlap.html)
- Bigger-card readability options: [`review/bigger.html`](review/bigger.html)
- Accessibility chrome scales (190 focus; **150% chosen**): [`review/accessible.html`](review/accessible.html)
- Window-filling table options (fluid bottom / side / cockpit): [`review/flex.html`](review/flex.html)
- One-line side-hand versions (fan / scroll / bottom): [`review/side-line.html`](review/side-line.html)
- S3 larger: six personas, four bigger-board options: [`review/s3-larger.html`](review/s3-larger.html)
- X2 backrow: face-up spells/traps are public, set cards stay secret: [`review/x2-backrow.html`](review/x2-backrow.html)
- The mat and Duel Board labs use actual `CardComposer` renders, not a CSS
  imitation; see [`review/README.md`](review/README.md#actual-card-renders).
- **or** serve the folder for a cleaner local URL:

```bash
cd review
python3 -m http.server 8765
# http://localhost:8765/
```

Sound is off by default; the speaker button enables the procedural impact and
pack sounds. The pack page has its own rating/notes/copy-feedback panel.

## Docs

- [`docs/WORKFLOW.md`](docs/WORKFLOW.md) — the review → lock → port → prove loop.
- [`docs/BUILD_STRATEGY.md`](docs/BUILD_STRATEGY.md) — the code migration route,
  token compatibility layer, shell order, and room order.
- [`docs/PLAN.md`](docs/PLAN.md) — current status, locked decisions, phases,
  acceptance gates, and the recommended order.
- [`docs/STYLE_NEON_RELIQUARY.md`](docs/STYLE_NEON_RELIQUARY.md) — the complete
  Neon Reliquary palette, type, materials, layout, motion, FX, sound, reuse, and
  Godot mapping.
- [`docs/RESPONSIVE_VIEWPORT_SPEC.md`](docs/RESPONSIVE_VIEWPORT_SPEC.md) — the
  fullscreen/windowed fit contract, safe rects, breakpoints, and test matrix.
- [`review/PACK_RITUAL.md`](review/PACK_RITUAL.md) — the pack ceremony's state
  machine and timings.

## Current build

- **Chosen direction:** Neon Reliquary.
- **Global shell:** four doors, same order everywhere — Play / Library / Decks /
  Packs; no second nav.
- **Table:** **R1 Cockpit Rail + H1/H2 hand + D2 Magnetic Drop**, a full-window
  table at **150% chrome**. The 5:7 card is never squashed. With the pinned rail
  the board is **184px at 1440×900**; at 1920 the full hand gives **209px**, and
  at 2560 it gives **294px**. The rail collapses for the full-width layout.
  - **B1 Front Row at ≥1280 width:** a face-up spell/trap is a public full card
    next to its monster. A set card stays face-down and secret.
  - **B3 Effect Ribbon below 1280:** a 40px ribbon lists every face-up effect
    in plain text; the full card stays available on click/inspect.
  - **Panel:** **R1 Cockpit Rail** at ≥1440 — a 288px pinned rail on the right,
    ending above the hand. The rail carries intent, log, inspect, actions,
    descent, the run strip, resolve, piles, and the four doors. Below 1440 the
    same panel is an edge overlay. The top-right button is labeled **PANEL**,
    with a collapse/expand chevron.
  - **Hand:** **H1 Readable Tray** at 1440–1919: 64% of the hand card width, so
    the name, seal, and type line are readable at rest; hover, focus, or click
    lifts the full face, and click pins it. **H2 Full Hand** at ≥1920 shows the
    full faces at rest. The hand spans the full window below the rail.
  - **Drag:** **D2 Magnetic Drop**. Drag a hand card to a glowing legal zone;
    the nearest legal slot within 24px captures it. Shift-drag sets; invalid
    drops snap back. Click-select remains as the fallback, and a player monster
    can be dragged onto an enemy monster to attack.
  - **Chrome:** **48px targets, 12–14px labels, an 82px score rail, and a 64px
    dock**. All three lanes stay visible; phase ticks sit on the score rail.
  - **Window:** the table fills the window it is given (minimum **960×720**) and
    keeps its current position. There is no forced 1000/960 square. The top nav
    hides; the panel carries the four doors (Play / Library / Decks / Packs),
    log, inspect, actions, piles, and PIN. The table starts pinned; leaving it
    restores the windowed shell rect.
  - **Fullscreen:** **F11** enters/exits fullscreen with exact window restore.
    The shell is contained in its 1440×900 canvas; the drawer, pile, zoom,
    confirm, result, and help surfaces fit with `FitPanel`. **F10** opens the
    dev viewport/safe-rect readout.
- **Rules:** the face is sealed while any enemy monster remains in a monster
  zone; this is enforced in `DuelRules`, not faked by the UI.
- **Packs:** **Waves 0–3 landed** — the rename, P1 Rip & Fan ceremony, and
  pack language are in the game. The door, screen, content IDs, settings, and
  saves use Packs; `folio.*` aliases and a v1 → v2 save migration keep old saves
  working. The sealed foil wrapper tears, the cards spill into a fan, each card
  turns on click, the tell is read from the committed rarity, and skip lands on
  the ledger. Evidence: `screenshots/pack_sealed.png`,
  `screenshots/pack_reveal.png`, and `screenshots/pack_click.png`.
- **Tests:** 419 passed, 0 failed. Layout audit passes at **15 windowed sizes
  plus fullscreen**, including the modal pass (960×720 through 3440×1440).
- **Seeded duels:** the seal shifts the Ember-vs-Damp-Warden matchup from
  72/17/11 (avg 10.4 turns) to 49/15/36 (avg 15.8 turns). That change is
  recorded in `docs/PLAN.md`; no balance rewrite has been made yet.
- **Duel Board:** the four same-size variants were reviewed; **Overlap** was
  chosen, then X2 Spring Shelf and the B1/B3 backrow were ported after the
  readability, accessibility, flex, and backrow labs.

Table evidence: `screenshots/table_x2.png` (1440 pinned rail + tray),
`screenshots/table_x2_1920x1080.png` (full hand), `screenshots/table_x2_drag.png`
(a magnetic drop), plus the older size set `table_x2_1280x720.png`,
`table_x2_2560x1440.png`, `table_x2_1000x1000.png`, `table_x2_960x960.png`, and
`table_x2_960x720.png`.

## What this round is

**Chosen direction: Neon Reliquary.** The table is now **X2 Spring Shelf**: a
full-window 150% table with a 30% hand shelf and public face-up spells/traps.
The next room is the **Pack Ritual** — the full Neon pack ceremony.

### Pack ritual

A complete interactive ceremony built on the real pack rules:

- sealed Brass Pack → crack → flap → 5-card fan
- honest rarity tells on the backs (pips + ring + label)
- 470 ms pinch-and-turn flips, 60 ms hold, escalating flares
- NEW / ×N stamps from the pre-open ownership snapshot
- a legendary moment for Razeah, the Unbound
- Quick / Auto / Skip; skip always lands on the ledger
- a summary strip that keeps the fan on screen and adds set progress
- three demo packs: Brass → Paper → Salvage, set 9 → 16 / 16
- synth cues, reduced motion, card zoom, full-screen theater
- rating/notes panel and copy-ready feedback

See [`review/PACK_RITUAL.md`](review/PACK_RITUAL.md) for the state machine,
timings, rarity grammar, data format, and the Godot `PackCeremony` mapping.

### Seven table directions

All built on one board skeleton:

1. **Lantern & Lacquer** — the séance table.
2. **Ink & Iron** — a woodcut brawl on butcher paper.
3. **Neon Reliquary** — an arcade cabinet possessed by a dead god.
4. **Hearth & Hollow** — a cozy storybook with teeth.
5. **Gilded Omen** — a tarot salon at the end of the world.
6. **Deepdelve** — torchlight on wet stone.
7. **Riso Rift** — a photocopied grimoire from 1987.

Every table is interactive:

- **CALL** the glowing Cinder Hound into Lane III.
- **STRIKE** Lane II with the Verdant Colossus.
- **END TURN** to let the Damp Warden answer.
- **AUTO** runs the whole turn as a broadcast: letterbox, lane spotlight, cue
  captions, score plates, staged damage, looped replay.
- **EXPAND** opens the table in a full-screen theater.

The top navigation is now exactly four doors: **Play / Library / Decks / Packs**.
In the table review, Play is wired and the Neon table's Packs door opens this
page; Library and Decks remain honest stubs. The pack page is the Packs room.

## The rule note

The three guard pips beside the Warden score are the rule made visible:
**the face is not attackable while the opponent has a monster in a monster
zone.** The rule is enforced in `DuelRules`; legal-action generation, AI, and
tests all agree. When the last guard leaves the board, the pips go dark and
direct strikes become legal.

## Reuse

- `review/js/data.js` — all game content, direction copy, palettes, and the auto
  cue sheet.
- `review/js/board.js` — the only board renderer. One DOM skeleton, one mount
  function, seven theme IDs.
- `review/css/board.css` — shared structure, card anatomy, FX, broadcast mode.
  All board measurements are `cqw`; card internals are `em`, so a card scales
  cleanly at any `--card-w`.
- `review/css/themes.css` — the seven token sets plus per-theme material
  overrides. Add a direction by adding one data record and one `[data-theme]`
  block.
- `docs/WORKFLOW.md` — the repeatable working loop.
- `docs/PLAN.md` — the phased build plan and acceptance gates.
- `docs/STYLE_NEON_RELIQUARY.md` — the locked style contract and reuse recipe.
- `review/README.md` — the table review's handoff notes and Godot mapping.
- `review/PACK_RITUAL.md` — the pack ceremony's state machine, timings, data
  format, and Godot mapping.

## Not built yet

- The P2 Reliquary Case and P3 Stack Peel skins, the stable-actor
  `PackCeremony` refactor, and the legendary flare. The P1 ceremony is in.
- The final cockpit polish: a collapsed-state intent chip, the keyboard lane
  picker, and the drag-ghost source residue.
- Library / Decks / Packs as full Neon rooms. The pack page is now a real
  ceremony, but it is not the final satchel inventory.
- Final sound design, localization, accessibility presets, and content pass.
- A post-seal balance pass. The rule changed the seeded matchup; the next
  candidates are AI guard-breaking and targeted content, not a rule rollback.

## Verification

**Game (2026-11-02):** 412 tests pass; layout audit reports 0 failures at
1280×720, 1440×900, 1800×1125, 1920×1080, 1280×1024, and 2560×1440. Table
screenshots at 1440×900 cover the idle board, a manual action, and Auto.

**Game (2026-11-05, Pack rename):** 419 tests pass; layout audit reports 0
failures at all 15 windowed sizes plus fullscreen. Content rebuilt with 5 packs;
v1 saves migrate to `pack_mode` and `pack.*` on load.

**Game (2026-11-05, Wave 1–3):** 419 tests pass; layout audit reports 0
failures at all 15 windowed sizes plus fullscreen. Table evidence at 1440
(pinned rail + tray), 1920 (full hand), and a magnetic drop; pack evidence for
sealed, reveal, and click-to-open. The pack screen and table both boot and
render through the test harness.

**Review labs:** both review pages were exercised in Chromium at 1440×1000 and
390×844, including file:// loading. Table: all seven boards, summon / strike /
end-turn / reset, autoplay looping, theater, shortlist, notes, copy-summary,
sound sync, motion. Pack: crack → fan → tells → common / rare / legendary flips
→ stamps → skip / reveal all / auto / quick → Brass → Paper → Salvage → set
16/16 → reset; zoom, theater, sound, reduced motion, notes, ratings, copy
feedback. No console errors. The stages scale as one object and scroll inside
their own frame on mobile.

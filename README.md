# Razeah Cards — V3

The new home for Razeah. V3 now contains the working Godot baseline, the Neon
Reliquary shell, and the rebuilt Neon Table. The approved review labs are still
here as the visual contract. V2 at `../RazeahCardsV2` remains the source of the
game rules and content.

## Run the game

```bash
godot --path .                 # play
tools/run_tests.sh            # 412 tests
tools/run_layout_audit.sh     # six reference sizes
```

The Table is reachable from **Play**. Library, Decks, and Packs are being ported
room by room into the same shell.

## Open the review

The review is a static site: no build step, no server required.

- Table direction review: [`review/index.html`](review/index.html)
- Chosen direction's pack ritual: [`review/packs.html`](review/packs.html)
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
folio sounds. The pack page has its own rating/notes/copy-feedback panel.

## Docs

- [`docs/WORKFLOW.md`](docs/WORKFLOW.md) — the review → lock → port → prove loop.
- [`docs/BUILD_STRATEGY.md`](docs/BUILD_STRATEGY.md) — the code migration route,
  token compatibility layer, shell order, and room order.
- [`docs/PLAN.md`](docs/PLAN.md) — current status, locked decisions, phases,
  acceptance gates, and the recommended order.
- [`docs/STYLE_NEON_RELIQUARY.md`](docs/STYLE_NEON_RELIQUARY.md) — the complete
  Neon Reliquary palette, type, materials, layout, motion, FX, sound, reuse, and
  Godot mapping.
- [`review/PACK_RITUAL.md`](review/PACK_RITUAL.md) — the folio ceremony's state
  machine and timings.

## Current build

- **Chosen direction:** Neon Reliquary.
- **Global shell:** four doors, same order everywhere — Play / Library / Decks /
  Packs; no second nav.
- **Table:** the Overlap Duel Board — two 900px-wide mats in a **1000 × 1000
  focus window** at **150% chrome**. One **190px 5:7 token** for hand,
  monsters, set cards, and deck back; the spell/trap card sits behind its
  monster with a **52px Index Tab** and lifts forward on hover. The chrome is
  **48px targets, 12–14px labels, an 82px score rail, and a 64px dock**. All
  three lanes stay visible; the score rail carries phase ticks, not phase names.
  The top nav hides in the focus window, so the drawer carries the four doors
  (Play / Library / Decks / Packs), log, inspect, actions, piles, and PIN. The
  table opens where the shell left the window and is pinned above other
  windows; PIN releases it and leaving the table restores the 1440 × 900 shell.
- **Smaller display:** **125% chrome at 960 × 960** with 44px targets, a 68px
  score rail, and a 56px dock. Same 190px cards and the same three lanes.
- **Rules:** the face is sealed while any enemy monster remains in a monster
  zone; this is enforced in `DuelRules`, not faked by the UI.
- **Tests:** 412 passed, 0 failed. Layout audit passes at all six reference sizes.
- **Seeded duels:** the seal shifts the Ember-vs-Damp-Warden matchup from
  72/17/11 (avg 10.4 turns) to 49/15/36 (avg 15.8 turns). That change is
  recorded in `docs/PLAN.md`; no balance rewrite has been made yet.
- **Duel Board:** the four same-size variants were reviewed; **Overlap** was
  chosen, then scaled to **190 focus + 150% chrome** after the readability and
  accessibility labs. Open [`review/bigger.html`](review/bigger.html) and
  [`review/accessible.html`](review/accessible.html) for the decision evidence.

Table evidence: `screenshots/table_focus.png` (1000×1000, 150%),
`screenshots/table_focus_960.png` (960×960, 125%),
`screenshots/table_focus_drawer.png`, and
`screenshots/table_focus_drawer_960.png` (the drawer doors at both scales).

## What this round is

**Chosen direction: Neon Reliquary.** The table is now the accessible Overlap
Duel Board: 190px cards, 150% chrome, a 1000 × 1000 focus window, and 125% at
960 when the display cannot hold the square. The next room is the **Pack
Ritual** — the full Neon folio ceremony.

### Pack ritual

A complete interactive ceremony built on the real folio rules:

- sealed Brass Folio → crack → flap → 5-card fan
- honest rarity tells on the backs (pips + ring + label)
- 470 ms pinch-and-turn flips, 60 ms hold, escalating flares
- NEW / ×N stamps from the pre-open ownership snapshot
- a legendary moment for Razeah, the Unbound
- Quick / Auto / Skip; skip always lands on the ledger
- a summary strip that keeps the fan on screen and adds set progress
- three demo folios: Brass → Paper → Salvage, set 9 → 16 / 16
- synth cues, reduced motion, card zoom, full-screen theater
- rating/notes panel and copy-ready feedback

See [`review/PACK_RITUAL.md`](review/PACK_RITUAL.md) for the state machine,
timings, rarity grammar, data format, and the Godot `FolioCeremony` mapping.

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

- The Folio ceremony in Godot. The HTML lab is approved; the stable-actor state
  machine is next.
- Library / Decks / Packs as full Neon rooms. The pack page is a review lab, not
  the final satchel inventory.
- Final sound design, localization, accessibility presets, and content pass.
- A post-seal balance pass. The rule changed the seeded matchup; the next
  candidates are AI guard-breaking and targeted content, not a rule rollback.

## Verification

**Game (2026-11-02):** 412 tests pass; layout audit reports 0 failures at
1280×720, 1440×900, 1800×1125, 1920×1080, 1280×1024, and 2560×1440. Table
screenshots at 1440×900 cover the idle board, a manual action, and Auto.

**Review labs:** both review pages were exercised in Chromium at 1440×1000 and
390×844, including file:// loading. Table: all seven boards, summon / strike /
end-turn / reset, autoplay looping, theater, shortlist, notes, copy-summary,
sound sync, motion. Pack: crack → fan → tells → common / rare / legendary flips
→ stamps → skip / reveal all / auto / quick → Brass → Paper → Salvage → set
16/16 → reset; zoom, theater, sound, reduced motion, notes, ratings, copy
feedback. No console errors. The stages scale as one object and scroll inside
their own frame on mobile.

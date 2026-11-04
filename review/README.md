# Razeah — Front-End Direction Review

**Neon Reliquary is the chosen direction.** The table lab is here; the pack
ritual is [`packs.html`](packs.html), with its own handoff in
[`PACK_RITUAL.md`](PACK_RITUAL.md). The scale and small-window pass is
[`mats.html`](mats.html); the Duel Board same-size variation lab is [`duel-board.html`](duel-board.html), and
[`bigger.html`](bigger.html) compares 180–220px readability budgets;
[`accessible.html`](accessible.html) scales the chrome around the chosen 190px
focus table, [`flex.html`](flex.html) compares window-filling layouts for 720p
through ultrawide, [`side-line.html`](side-line.html) compares one-line versions
of the Fluid Side hand, [`s3-larger.html`](s3-larger.html) is the six-persona
follow-up that makes the S3 board bigger, and [`x2-backrow.html`](x2-backrow.html)
settles the face-up spell/trap visibility question. The durable build contract lives in
[`../docs/STYLE_NEON_RELIQUARY.md`](../docs/STYLE_NEON_RELIQUARY.md); the phased
plan is [`../docs/PLAN.md`](../docs/PLAN.md).

A one-page lab for choosing the look and feel of the Razeah table. Seven skins,
one skeleton, one live interactive turn, and an autoplay broadcast.

Open `index.html` directly, or:

```bash
cd review
python3 -m http.server 8765
```

Sound is off by default. The speaker button in the review masthead and the one
inside every table share the same state. All audio is synthesised in the browser
with WebAudio; there are no audio files.

## Twin mats

The first two scale passes were rejected: they hid lanes in tabs, repeated state
in labels, and still kept the board more dashboard than tabletop. The third pass
keeps all three lanes visible and removes the subtitles:

- **Twin Mat** — 1360 × 900. Two mats, scores at the table edge, 190px cards,
  no lane numbers, no OPEN/CALL, no guard sentence.
- **Clash Rail** — 1360 × 900. Both scores and the last consequence live on the
  center seam; for Auto.
- **Table Edge** — 1360 × 900. Scores and actions printed on the mat borders;
  no separate HUD.
- **Corner Mat** — 640 × 800. All three lanes at the pinned size; 150px cards.
- **Side Bench** — 1360 × 900. The hand moves to a side ledge; 220px cards.
- **Long Table** — 1360 × 900. Two mats side by side; the lanes become rows.
- **Ledger Rail** — 1360 × 900. A scorekeeper column on the left; 190px cards.
- **Duel Board (mixed-size reference)** — 900 × 900. The original square preview:
  165px board cards, a 96px hand, and 64px set-card peeks. Kept for comparison;
  the corrected same-size variants live in [`duel-board.html`](duel-board.html).

Empty slots are ghost cards with a plus; guards are lock pips; intent is a pink
target bracket; phase is six seam ticks. The Duel Board lab chose **Overlap**;
the mats page remains the scale reference. The rejected passes are kept at
`readability.html` and `surfaces.html` for comparison only.

## Duel Board lab

[`duel-board.html`](duel-board.html) is the focused lab for the chosen square
table. The rule is one 5:7 card token per board: hand, monster row, spell/trap
row, and deck back are the same size. Four budgets fit all three lanes inside
900 × 900:

- **Grid** — every card 105px; both spell/trap rows and both monster rows fully
  visible.
- **Overlap** — every card 145px; the spell/trap card is the same size, tucked
  behind the monster.
- **Shelf** — every card 120px; full rows plus a side hand shelf.
- **Mirror** — every card 120px; two mats side by side, each lane a row with a
  monster column and a spell/trap column.

**Chosen: Overlap.** It is the biggest card budget that still fits the full hand
and all three lanes inside 900 × 900. The spell/trap card is the same 145px
token, with the **Index Tab 44** cut: a 44px side tab behind its monster and a
hover lift to the full card. The follow-up [`overlap.html`](overlap.html) lab
compares four core tucks plus five Side Spine cuts, the spread-on-hover fix, and
the upgrade list. Top Peek and Side Spine have live view/face/peek controls so
the tabbed card can be inspected.

Every board contains no state labels. `aria-label`s and the review copy carry the
meaning. The exchange is the actual Cinder Hound / Bramble Wall stat line:
Cinder Hound catches Bramble Wall in Attack Position for 900, and KINDLE burns
the Warden for 200.

## Actual card renders

The review cards are PNGs rendered by the shipping `CardComposer`, not a second
CSS card renderer. They live in `review/assets/cards/` and are displayed through
the same `.card-slot` boxes as the game. Regenerate them after changing card
anatomy, tokens, or content:

```bash
godot --path . res://tools/export_review_cards.tscn
```

`tools/export_review_cards.gd` renders each face at 300 × 420 (the L token) at
2× for crisp downscaling, plus the card back. The review folder is ignored by
Godot, so these PNGs are review evidence, not game art.

## Readability lab

[`bigger.html`](bigger.html) answers the next problem after Index Tab 44: at
145px the table is readable as a board but not as a card. It compares five
actual-size budgets:

- **A — 180 / same window:** 960×960 with nav; bottom hand; +24%.
- **B — 190 / focus window:** 960×960 without the top nav; +31%.
- **C — 190 / taller window:** 960×1012 with nav; +31%.
- **D — 200 / bottom hand:** 1060×1012; +38%.
- **E — 220 / tall table:** 1160×1096; +52%.
- **F — detail lens:** keep 145; read at 300px on demand.

All keep the 44px Index Tab and one card size per table. The page has a
**Fit frames** toggle so the 960–1160 frames can be compared in a narrow pane.

## Accessibility lab

[`accessible.html`](accessible.html) keeps the chosen **190px focus** card and
grows the chrome around it: labels, buttons, borders, pips, ticks, score bars,
dock, and the Index Tab. The scales are:

- **100% / 960** — the baseline; 22px buttons and 7px labels.
- **150% / 1000** — 48px buttons, 52px tab, 12–14px labels, 2px borders.
  **Chosen** low-vision mode; 8px of board slack.
- **125% / 960** — 44px buttons, 52px tab, 10–12px labels; same-window fallback;
  the 960 proof is exact, so the port adds 4px.
- **200% / 1200** — 56px buttons, 16px labels; desktop maximum.

All keep the 190px card, all three lanes, the bottom hand, and the Index Tab.
The chosen scale is **150% at 1000×1000**. The card is never shrunk to make the
chrome fit.

First ported to Godot on 2026-11-03 as the 190px / 1000×1000 focus table.
The live table has since moved to **X2 Spring Shelf** (2026-11-04): it fills the
window at 150% chrome, scales the 5:7 card, uses B1/B3 backrow, and keeps the
30% hand shelf. Evidence: `screenshots/table_x2_1440x900.png`,
`table_x2_1920x1080.png`, `table_x2_1000x1000.png`, and
`table_x2_hand_1440x900.png`.

## Flex lab

[`flex.html`](flex.html) starts from the 150% table and asks what happens when the
window is not 1000×1000. At the time of the lab the board capped at 900 and the
card at 190; at 2560×1440 that was 35% of the screen width. The page compares four
layouts with a live window selector from 1280×720 to 3440×1440:

- **A — fixed 190:** the 1000×1000 baseline. 35% width at 2560.
- **B — fluid bottom:** bottom hand, 123–294 card. Fits any window; leaves wide
  side gutters at 16:9.
- **C — fluid side:** two-column hand on the right, 144–443 card. Fills 94–95%
  of the width and 85–89% of the board height at 1920/2560; drawer moves left.
- **D — docked cockpit:** B-sized cards plus a persistent 260–440px log/actions
  rail. Keeps the bottom hand and removes the overlay; uses about 60% of 2560.

The recommendation was **Hybrid: C in landscape, B in square**. The matrix shows
the card budget at every size; the page's Fit frames toggle makes the 1920/2560
tables comparable in a narrow pane. The live X2 table now fills the window rather
than forcing the old square.

## Side hand, one line

[`side-line.html`](side-line.html) is the follow-up to Fluid Side: the hand is one
line, not two columns. It keeps the same two-card-height board budget in the side
variants and compares:

- **S1 — side fan:** one vertical line, older cards at 20%, newest full, no scroll;
  315 at 1920, 250 at 1440, 191 at square.
- **S2 — side scroll:** one vertical line, three cards readable at 50% overlap,
  scroll for the rest; same card sizes as S1.
- **S3 — bottom row:** one horizontal line, all six cards readable, no cover;
  board returns to the bottom-hand size (209 at 1920, 166 at 1440, 190 at square).

The one-column hand uses `4c + 226` instead of the two-column `5c + 226`. At
1920/2560 the card size matches the two-column layout; at 1440 it gains 10px and
at square it gains 39px. The page recommended **S2** for max card with a readable
scroll, or **S3** when the full hand must be visible. The live X2 table uses the
bottom **Spring Shelf** (30% visible, hover/focus/click lift).

## S3 larger

[`s3-larger.html`](s3-larger.html) turns "S3 is too small" into a six-person
design review. The team — tabletop UX, accessibility, stage design, information
architecture, responsive systems, and player psychology — keeps S3's one-line
bottom hand and compares:

- **X1 Wall Chrome:** 240px score/action wall; full hand; **245** at 1920.
- **X2 Spring Shelf:** 30% hand shelf; hover/focus/click lifts the full card;
  **283** at 1920; the team pick.
- **X3 Open Table:** mats side by side; full hand; **247 / 354 / 450** at
  1920 / 2560 / 3440; wide only.
- **X4 Hand Index + Lens:** 60px name/stat tabs plus a full-card lens; **292** at
  1920; one face at a time.

S3 remains the reference at 209. The page has a size matrix from 960² to
3440×1440 and a team vote. **X2 Spring Shelf is now the live table.**

## X2 backrow

[`x2-backrow.html`](x2-backrow.html) is the team's answer to the hidden
spell/trap. The rule is: a face-down set card stays secret; a face-up spell or
trap is a public rule and must be visible without a hover. It compares:

- **B0 current:** face-up card behind the monster; 52px tab; effect hidden.
- **B1 Front Row:** face-up card full next to its monster; 283 at 1920; set
  card keeps the 52px tab; **team pick at 1920+**.
- **B2 Effect Tabs:** face-up card behind a 141px tab carrying the effect text;
  full face on click; narrow-board option.
- **B3 Effect Ribbon:** 40px text ribbon above the board; 270 at 1920; 244 at
  1000; **square answer**.
- **B4 Backrow Rail:** X2 board plus a 292px side gallery; two full faces and
  a scroll; **1440 compact**.

The new spell/trap review renders are Bone Orchard, Hollow Lantern, Tidecall,
Quiet Ledger, and Ninefold Seal. Every option keeps the X2 hand shelf.

## Pack ritual

The chosen direction's pack-opening ceremony is a second page:

- sealed folio → crack → flap → 5-card fan
- pips + ring + label tells, read from the committed rarity
- 470 ms pinch-and-turn flips with a paper edge and 60 ms hit-stop
- escalating flares; legendary gets a room-wide local bloom and a banner
- NEW / ×N stamps from the pre-owned snapshot
- Quick / Auto / Skip; skip lands on the ledger
- a ledger strip that keeps the fan on screen
- three demo folios, set 9 → 16 / 16
- zoom, theater, sound, reduced motion
- ratings, notes, copy feedback

See [`PACK_RITUAL.md`](PACK_RITUAL.md).

---

## What you are looking at

The shipping table now follows the **Overlap Duel Board** in
[`duel-board.html`](duel-board.html). The list below describes the original
seven-direction review lab, kept as the visual history.

Each direction is a complete table, not a colour swatch:

- **Play / Library / Decks / Packs** at the top: the four-door navigation.
- **Warden strip (original lab):** name, resolve, guard count, hand and deck.
- **Three lanes:** enemy monster and backrow, player monster and backrow.
- **Player rail:** resolve, deck, remains, void.
- **Intent rail:** the Warden's next action, a lane map, and the table log.
- **Hand fan:** one playable card is lit; the rest are demo stubs.
- **Action dock:** Strike, End Turn, Reset.
- **AUTO:** a full choreographed turn that loops.

The layout is identical in all seven directions on purpose. You are judging the
skin, the motion, the voice, and the amount of noise — not a moving layout.

## Try this

1. Click the glowing **Cinder Hound** in hand. It flies into Lane III and
   triggers KINDLE for 200 into the Warden's resolve.
2. Hit **STRIKE**. The Verdant Colossus breaks the Tidebound Archivist in Lane
   II, the guard count drops, and the lane opens.
3. Hit **END TURN**. The Warden answers in Lane II; the Colossus drops to 400 DEF.
4. Hit **RESET TABLE**, then **AUTO**. Watch the whole loop.
5. Hit **EXPAND** to judge the board full-screen.
6. **Shortlist** directions, leave **Notes**, then **Copy review summary** and
   paste it into the chat.

## Files

```text
review/
  index.html          table direction review
  packs.html          the Neon pack ritual (chosen direction)
  readability.html    rejected first pass (kept for reference)
  surfaces.html       rejected second pass: four surfaces
  mats.html           third pass: two mats, all lanes, no state labels
  duel-board.html     four same-size Duel Board variants
  overlap.html        four core tucks + five Side Spine cuts
  bigger.html         actual-size readability tables + detail lens
  accessible.html     190 focus + 125/150/200% chrome accessibility lab
  assets/
    current-table.png current 1440 table, used in the diagnosis
    cards/            actual CardComposer renders for the mat and Duel Board labs
  css/
    review.css        editorial shell, hero, index, stage, decision
    board.css         shared board skeleton, cards, lanes, FX, auto
    themes.css        seven token sets + per-theme material overrides
    pack.css          satchel room, envelope, fan, tells, flares, ledger
    readability.css   shared shell/cards for the scale labs
    surfaces.css      second-pass surface compositions
    mats.css          third-pass twin-mat compositions
    duel-board.css    four Duel Board card-budget variants
    overlap.css       overlap examples, pocket, spread, upgrades
    bigger.css        readability tables, hand shelves, fit frames
    accessible.css    large-type chrome, 44–56px targets, score/dock scale
    flex.css          fluid table budgets, side hand, docked cockpit, window picker
    side-line.css     one-column side hand, fan/scroll, bottom-row variant
    s3-larger.css     team cards, wall rail, spring shelf, arena, lens rail
    backrow.css       front-row lanes, tucked tabs, effect tabs, ribbon, rail
  js/
    data.js           content, direction copy, autoplay cue sheet
    icons.js          procedural SVG glyphs
    sound.js          WebAudio synth (no audio files)
    board.js          one board renderer + interaction + FX
    pack-data.js      three folios, tell grammar, beats, ethics
    pack.js           FolioCeremony state machine, modes, FX, zoom, feedback
    review.js         shortlist, notes, theater, copy, nav
    readability.js    first-pass cards, exchange demo, pick memory
    surfaces.js       second-pass cards, exchange, pick memory
    mats.js           third-pass card renders, exchange, pick memory
    duel-board.js     Duel Board card renders, exchange, pick memory
    overlap.js        overlap view/face/peek controls
    bigger.js         fit-to-pane for the actual-size tables
    flex.js           window selector, card-budget solver, fit-to-pane
    side-line.js      one-line side-hand selector and card budget
    s3-larger.js      fit frames, shelf reveal/pin, lens tab switcher
```

No build step. No bitmap art in the game. The review labs use PNG renders of
the shipping `CardComposer` in `assets/cards/`, generated by
`tools/export_review_cards.gd`; every other ornament is CSS or inline SVG.

## The reuse contract

**One renderer.** `board.js` builds the same DOM for every direction. The theme
is a `data-theme` attribute on the board and on standalone card scopes. A new
direction is:

1. Add a record to `RAZEAH.themes` in `data.js` (name, palette, copy, risk).
2. Add a `[data-theme="new-id"] { ... }` token block in `themes.css`.
3. Add any material overrides scoped to that theme.

No new board code, no new card code, no forked HTML.

**Board units.** The board is one `container-type: inline-size` object sized in
`cqw`; it scales as a single composition. The board's 16:10 aspect ratio matches
the 1440×900 game reference.

**Card units.** Every card is 5:7 and sized by `--card-w`. Card internals are in
`em`, so the same card component works in the lane (`--card-w: 7.8cqw`), in the
hand (`9.1cqw`), in the rack (`132px`), or in the hero fan. Card anatomy never
changes: nameplate → seal → type line → rules → stat plate → footer.

**Theme surface.** A theme can change:

- palette and texture
- display / UI / mono / caps typefaces
- card material, frame, seal treatment, and shadow
- panel silhouette, border, radius, ornament
- lane material, seam, and watermark treatment
- button material, score plate, toast, caption
- ambient mote shape/colour and idle motion
- FX shape and colour

A theme must not change:

- the four doors or their order
- the lane order, score rail, two mats, hand, action dock, or drawer
- the card's 5:7 geometry or six-band anatomy
- the source → target → residue feedback contract
- the face-sealed guard pips

## Porting to Godot

The review is intentionally shaped like the eventual Godot split:

| Review | Godot home |
|---|---|
| `data.js` theme records / CSS tokens | `Tokens.gd` + `ThemeBuilder` |
| `board.js` shell + state | `TableScreen` / `BattleStage` |
| Duel Board mats, score rail, 44px tab | `DuelBoardStage` |
| `.rz-card` + card anatomy | `CardComposer` (single bake point) |
| Autoplay cue sheet / timing | `BattleDirector` |
| `.rz-fx` particles, plates, floats | `FxLayer` |
| `sound.js` | new `AudioDirector` |
| Four-door nav | `App` |
| Directions' copy | content / flavour, not code |

The intended refactor is **not** seven code paths. It is one set of scene
components, one set of theme tokens, and content data per direction.

## Scope and honest stubs

This review is about the table and the feel of autoplay. It is not the full game:

- Library, Decks, and Packs are visible doors but honest stubs.
- Only one card is callable; other hand cards show a demo notice.
- Strike always targets Lane II; full lane targeting belongs to the refactor.
- The pack-opening screen is not built. The feel contract and the autoplay loop
  establish the grammar it should use.
- Sound is a lightweight procedural sketch, not final design.
- The board's card text is deliberately small at 1440, matching the game's card
  scale; use Expand or the skin rack to inspect card faces.

## Verification notes

Checked in Chromium at 1440×1000 and 390×844, from both `http://` and `file://`:

- all seven boards mount and scale
- summon, strike, end turn, reset
- autoplay: captions, lane focus, score plates, damage, loop, fade reset
- theater open/close (Escape included)
- shortlist persistence, notes persistence, copy summary
- sound toggle sync across masthead and every board
- motion toggle
- no console errors; no page-level horizontal overflow

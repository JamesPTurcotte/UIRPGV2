# Build Strategy — Neon Reliquary

How the existing V2 game becomes the Neon V3 game without rewriting the rules,
content, saves, or tests. This is the code-level companion to `PLAN.md`.

## The core decision

**Strangler port, not a big-bang rewrite.**

Keep the V2 domain, application, content pipeline, save model, and test suite.
Replace the presentation from the outside in:

1. import the working game as the baseline;
2. remap the style surface to Neon;
3. move global navigation into `App`;
4. restyle the shared card / chrome / overlay components;
5. refactor each room onto the new shell and card system;
6. port the table choreography and the pack ceremony;
7. prove, screenshot, document, repeat.

The game stays playable after every step. No step may leave V3 unbootable or the
domain suite red.

## Why this is the smart route

The V2 presentation is already token-driven:

- `Tokens` owns colours, fonts, card sizes, panel styles.
- `ThemeBuilder` owns standard controls.
- `UI` owns screen construction helpers.
- `Chrome` owns procedural ornament.
- `CardComposer` is the single card face.
- `App` already hosts and routes screens.
- `UIScreen` already gives every room a common lifecycle.

That means the first visual change is **not seven screen rewrites**. It is:

```text
Tokens + ThemeBuilder + Backdrop + Chrome + CardComposer + App shell
        ↓
one global Neon skin across every room
        ↓
screen-by-screen layout and choreography
```

Do not duplicate any of those layers while migrating. The only acceptable
temporary duplicate is a compatibility alias in `Tokens`.

## The migration surface

### 1. Baseline

Copy the V2 project into the V3 root, excluding caches, `.godot`, screenshots,
the Python venv, and V2's own README/docs. Keep V3's `docs/` and `review/`.
Add `.gdignore` files so Godot ignores the review labs and docs.

Acceptance: the game boots, the suite runs, the old table/pack screenshots are
captured for comparison.

### 2. Token compatibility layer

The V2 code references names such as `Tokens.BRASS`, `Tokens.BG_LACQUER`,
`Tokens.PAPER`, and `Tokens.WAX` in hundreds of places. Do **not** mass-rename
call sites first. Instead:

1. Add the semantic Neon names:
   `BG_VOID`, `BG_PANEL`, `BG_RAISED`, `INK_PRIMARY`, `INK_SECONDARY`,
   `CYAN`, `PINK`, `AMBER`, `GREEN`, `PURPLE`, `CARD_FACE`, `CARD_INK`,
   `CARD_RULE`, etc.
2. Map the legacy names onto Neon values for the compatibility pass:
   `BRASS → CYAN`, `BRASS_HI → PINK`, `BG_LACQUER → BG_DEEP`,
   `PAPER → CARD_FACE` (cards and paper objects become dark glass),
   `PAPER_INK → CARD_INK`, `WAX → PINK`, `VERDIGRIS → GREEN`,
   `SELECTION → AMBER`, `GOLD → AMBER`.
3. Update shared components to use the semantic names.
4. Migrate screens to semantic names only when that screen is refactored.
5. Delete the legacy aliases after the last screen is ported.

This gives the whole game a coherent Neon palette and type system in one step
while keeping every call site compiling.

### 3. Global shell

Move the four doors into `App`, not into each screen:

```text
App
  Backdrop
  TopNav          Play · Library · Decks · Packs · resources · settings
  Host (content)  current UIScreen fills the space below TopNav
  Overlay         zoom / confirm / menus
  ToastLayer
```

- `App` owns the active-door state and routing.
- Play goes to the Gate when no descent is active, otherwise the Table.
- Library goes to the Library; Decks to the Deck Workshop; Packs to the Pack.
- Bench is a Library sub-room; Salvage is a Play sub-room; the active door
  remains Library/Play.
- The old per-screen top bars are replaced by a local page header inside the
  room. Contextual actions (Gate, Deck, Packs) move into the global nav or the
  room's own content, never into a second top nav.
- The run strip stays inside the Play/Table room.

### 4. Shared visual system

Do these before screen-specific layout:

- `ThemeBuilder`: Neon backgrounds, borders, focus, hover, pressed, tooltips,
  scrollbars, popups.
- `Backdrop`: void gradient, grid, scanlines, grain, vignette, room glow.
- `Chrome`: clip corners, Neon borders, scanline/grid panels, Warden seal,
  rarity gems, gauge, score plate, banner, corner brackets.
- `CardComposer` + `SealComposer`: dark glass card, attribute border, procedural
  seal, rarity dot, type/rule/stat/footer treatment. Keep the 5:7 anatomy and
  the existing single bake point.
- `UI`: buttons, panels, chips, display/data/label styles, focus. Make
  `small_caps` use the Neon label face and `display` use Orbitron.

After this step every screen should look Neon, even before its layout is
refactored. That is the checkpoint that proves the token surface is complete.

### 5. Room order

| Order | Room | Why |
|---:|---|---|
| 1 | **Table** | Core loop; proves actors, director, score plates, Auto. |
| 2 | **Pack** | Already designed in the lab; proves the pack ceremony. |
| 3 | **Library** | The home room; shelves and reading desk. |
| 4 | **Gate** | Entry to Play; depth rail and descend medallion. |
| 5 | **Deck Workshop** | Reuses Library filters/cards. |
| 6 | **Bench** | Crafting room; shares card actions. |
| 7 | **Salvage** | Run result; shares ledger language with the pack. |

Each room follows the same loop:

1. replace its top bar / margins with the Neon shell and local page header;
2. keep the existing logic and data flow;
3. recompose the layout with the shared panels/buttons/cards;
4. move local colours/sizes into Tokens/UI;
5. add the room's signature FX/motion only after the layout is stable;
6. run the layout audit, take screenshots, update the plan.

### 6. Table and pack are their own projects

The table needs a structural rewrite:

- stable `CardActor` per uid;
- rest targets and a `BattleDirector`;
- X2 Spring Shelf composition: full-window 150% chrome, dynamic 5:7 card,
  B1 Front Row at ≥1280 / B3 Effect Ribbon below, a 30% hand shelf, a deck
  strip, score rail, dock, drawer, and four doors in the drawer;
- staged damage, score plates, Auto captions;
- face-sealed rule in `DuelRules`.

The pack needs a state machine:

- `PackCeremony` owns beats and input;
- stable envelope/fan/cards;
- exact tells, flips, flares, stamps, skip-to-ledger.

These are specified in `STYLE_NEON_RELIQUARY.md` and
`../review/PACK_RITUAL.md`. They are not part of the token pass.

## Testing gates

Every step ends with:

```bash
tools/run_tests.sh
tools/run_layout_audit.sh
```

plus the appropriate screenshots:

- shell / library / gate / pack / deck / bench / salvage: 1280, 1440, 1920;
- table: 1280, 1440, 1920 plus manual / Auto / end states;
- pack: sealed / fan / rare / legendary / summary;
- reduced motion and sound-off for each interactive screen.

A visual step is not done until it has a screenshot at 1440 and the suite is
green.

## What stays untouched

- `src/domain/` except the face-sealed rule and its tests.
- `src/application/` except navigation/settings plumbing.
- `content/` and `tools/build_content.py`.
- `tests/` except new visual/behavior coverage.
- The 5:7 card anatomy and the no-bitmap rule.

## Anti-patterns

- Do not build a second theme system or a second card composer.
- Do not copy the HTML/CSS lab into Godot; port values and behaviour.
- Do not keep a per-screen nav after the global nav lands.
- Do not mass-rename every token before the compatibility layer works.
- Do not rewrite a screen's logic while also reflowing its layout.
- Do not port a screen from a static mock; port the working screen and improve
  it.
- Do not claim a screen is done without the layout audit and screenshots.

## Working log

Add one line to `PLAN.md` per completed step:

```text
[date] Step N — <what changed> — suite X/Y — screenshots <paths> — next <step>
```

The plan is the source of truth for the next session; the build is not done
until the log says so.

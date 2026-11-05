# Neon Reliquary — Style Contract

The chosen look and feel for Razeah. This is a build recipe, not a mood board:
tokens, type, materials, layout, motion, FX, sound, and the rules for reusing
them in every new room.

**Reference labs:** [`../review/index.html#neon`](../review/index.html#neon) ·
[`../review/packs.html`](../review/packs.html)
**Source tokens:** [`../review/css/themes.css`](../review/css/themes.css)
(`[data-theme="neon"]`)
**Source components:** [`../review/css/board.css`](../review/css/board.css),
[`../review/css/pack.css`](../review/css/pack.css)

> The labs are the visual reference. The game does **not** import them. Recreate
> the values in `Tokens.gd` / `ThemeBuilder` / `CardComposer`.

---

## 1. Identity

**A dead god's arcade cabinet, run by a keeper with a ledger.**

Razeah's table is black glass and cold light. Ion cyan is the system; hot magenta
is the wound; amber is the money and the rare. The Warden is not a portrait — it
is a seal, a title, an intent, and a voice. The cards are the only objects allowed
to be bright.

The style is built from:

- **Material:** black glass, bone ink, brass, wax, wet stone, scanlines.
- **Light:** cyan rim light, magenta event light, amber number light.
- **Type:** an arcade sans, a terminal data face, a clean rules face.
- **Motion:** punch, freeze, residue. Never floaty UI.
- **Voice:** dry, precise, warm; never a casino.

No illustrations. No portraits. No painted backgrounds. No bitmap textures.
Every ornament is geometry, type, gradient, or a procedural glyph.

## 2. Non-negotiables

1. Four doors only: **Play / Library / Decks / Packs**.
2. Cards are **5:7** at every size, with fixed six-band anatomy.
3. One renderer, one token file. A room is a composition, not a fork.
4. No colour-only signal. Pair colour with a glyph, a pip count, or a label.
5. Every action speaks: number, movement, mark, or sound.
6. Anticipation → impact → residue on every meaningful action.
7. The result is committed before the ceremony; the tell is exact.
8. Skip is first-class; reduced motion keeps the information.
9. No fake near-miss, reroll, urgency, or casino feedback.
10. The table is not a spreadsheet. The cards are the heroes.

## 3. Palette

The canonical values live in `themes.css`. In Godot, add them to `Tokens.gd`.

| Token | Hex | Use |
|---|---|---|
| `VOID` | `#06030D` | page/room base |
| `PANEL` | `#0D071E` → `#070414` | glass panels |
| `PANEL_2` | `#0E0822` | raised glass |
| `INK` | `#F4ECFF` | primary text, card rules on dark faces |
| `MUTED` | `#9C8FBE` | body copy, labels |
| `FAINT` | `#6E638C` | tertiary labels, disabled |
| `CYAN` | `#46F0FF` | interactive, focus, neutral rim light, DEF |
| `CYAN_SOFT` | `rgba(70,240,255,.20)` | glows, focus fields |
| `PINK` | `#FF3FA4` | primary action, legendary, damage, active Packs |
| `AMBER` | `#FFCC55` | marks, numbers, rare, guards, prompts |
| `GREEN` | `#7DFFB2` | uncommon, good, heal |
| `PURPLE` | `#B06BFF` | umbra, Warden intent, legendary ambience |
| `EMBER` | `#FF5B7F` | ember attribute |
| `TIDE` | `#46F0FF` | tide attribute |
| `VERDANT` | `#7DFFB2` | verdant attribute |
| `UMBRA` | `#B06BFF` | umbra attribute |
| `NEUTRAL` | `#F4ECFF` | neutral attribute |
| `RARITY.common` | `#9AA0B5` | common dot/tell |
| `RARITY.uncommon` | `#7DFFB2` | uncommon dot/tell |
| `RARITY.rare` | `#FFCC55` | rare dot/tell |
| `RARITY.legendary` | `#FF3FA4` | legendary dot/tell |

> The Neon theme remaps the card's rarity dot to this brighter tell palette
> (`review/css/themes.css`, `[data-theme="neon"] .rz-rarity-*`). Use one
> mapping everywhere: the back tell, the card dot, the flare, and the summary
> pip. The base V2 rarity colours remain the fallback for non-Neon themes.

### Colour discipline

- **Cyan is the system.** Lines, tabs, focus, lane rails, safe interaction.
- **Pink is an event.** Primary action, legendary, damage, Packs active. If
  everything is pink, nothing is.
- **Amber is accounting.** Numbers, marks, rare, guards, "open another".
- **Green is a positive state**, not a decoration.
- **Purple is the Warden / umbra.** Use it for intent and atmosphere.
- **Body text is never Orbitron.** Long rules use Inter.
- **No colour-only signal.** Always add pips, rings, labels, or glyphs.
- **Keep long copy on `INK` or `MUTED`.** Cyan/pink/amber are label colours.

### Background recipe

```css
background:
  radial-gradient(55% 45% at 50% 108%, rgba(70,240,255,.15), transparent 66%),
  radial-gradient(36% 40% at 100% 0%, rgba(255,63,164,.12), transparent 70%),
  radial-gradient(30% 36% at 0% 100%, rgba(176,107,255,.10), transparent 70%),
  linear-gradient(180deg, #06030d 0%, #0a0518 58%, #05020b 100%);
```

Layered on top:

- a **grid** (3 cqw at 1440) at ~4.5% cyan, masked from the top;
- **scanlines** 1 px / 3 px at low opacity, screen blend;
- **grain** at 3–5%;
- **vignette** and a soft magenta pool behind the hero object.

The grid and scanlines are texture, not content. Never put them over card text at
a strength that reduces contrast.

## 4. Type

| Role | Family | Rules |
|---|---|---|
| Display / nav / card names / buttons | **Orbitron** 500–800 | Uppercase, tracking `.04em`–`.16em`; never body copy. |
| Numbers / stats / logs / data | **VT323** | Natural size for numbers; tabular; cyan/pink/amber. |
| Rules / body / UI prose | **Inter** 400–600 | Line-height 1.2–1.6; 4.5:1 minimum. |
| Small system labels | **IBM Plex Mono** 400–500 | 8–10 px at 1440; tracking `.08`–`.16em`. |
| Pack/pack labels | Orbitron + VT323 | Pips/labels use VT323 or Plex Mono. |

### Scale on the 1440 board

These are the lab sizes; port them as relative tokens, not fixed pixels.

- room title `0.78 cqw` (Orbitron)
- nav tab `0.55 cqw` (Orbitron)
- Warden name `1.25 cqw` (Orbitron, uppercase)
- card name `0.68 em` of card width (Orbitron, uppercase)
- card rules `0.54 em` (Inter)
- card stats `1.15 em` (VT323)
- status line `0.54 cqw` (VT323/Plex)
- ledger numbers `1.25 cqw` (VT323)
- card width drives the type: `font-size = card_width / ~10`; don't use a single
  fixed card font size.

Card text is small by design at 1440. The card zoom and inspector are part of
the readability contract, not optional.

## 5. Surfaces and materials

### Glass panel

- Background: `linear-gradient(180deg, rgba(13,7,30,.92), rgba(7,4,20,.92))`.
- Border: 1 px `rgba(70,240,255,.25)`.
- Clipped corner: `.55 cqw` (top-right or bottom-left).
- Inner top highlight: 1 px white at 4–6%.
- Outer glow: `0 0 ~1 cqw rgba(70,240,255,.08)`.
- No large border radius. No glassmorphism blur as a decoration; blur is for
  modal backdrops only.

### Score rail (shipping)

- Left: `YOU`, resolve in VT323, thin resolve bar.
- Center: six phase ticks. The active tick lights; no phase names.
- Right: Warden name, resolve, three guard pips. Lit pips = guards; the face is
  sealed while any pip is lit.
- No Warden strip, guard chip, intent sentence, or lane numeral on the board.
- The drawer carries the four doors, detailed intent, log, inspect, actions,
  piles, speed, and the PIN control. The table keeps the shell's current window
  position, starts pinned, and restores the shell window on exit; PIN releases it.

### Mats, backrow, and shelf (shipping X2 Spring Shelf)

- Two mats stacked, one row of three slots per mat. The card is always 5:7 and
  scales with the window; it is never squashed to fit a lane.
- **B1 Front Row at ≥1280 width:** each lane is a monster plus a face-up
  spell/trap seat. A face-up card is public and full size; a set card stays
  face-down and secret. The board is `6c + 48` wide.
- **B3 Effect Ribbon below 1280:** the card stays tucked behind its monster with
  the 52px side tab, and a 40px ribbon above the board lists every face-up
  effect in full text. The full face stays one click/inspect away.
- All three lanes are always visible. Empty slots are ghost cards with a plus;
  legal zones get amber brackets; the threatened lane gets a pink bracket.
- The active mat edge glows at the seam. No tabs, focus lane, hidden lane, or
  lane numerals.
- **Hand:** the bottom **30% shelf**. Only the title strip is visible; hover,
  focus, or click lifts the full face and click pins it. The deck shows the same
  strip with its count. Cards overlap only when the window cannot fit the step.

### Card face

The shipping face comes from `CardComposer` and keeps the V2 fixed anatomy. The
mat and Duel Board labs display actual `CardComposer` renders (2× the L token,
exported by `tools/export_review_cards.gd`), not a CSS imitation, so the review
and the game share the same face. The older rejected labs still show the CSS
sketch for comparison.

```text
nameplate → seal → type line → rules → stat plate → footer
```

The Neon treatment:

- **Face:** `linear-gradient(160deg, #0d0820, #070410)`, 1 px attribute-colour
  border, clipped corner, inner cyan-low grid.
- **Nameplate:** Orbitron uppercase, `INK`; rarity dot at right.
- **Seal window:** near-black; procedural grid + scanlines; attribute glyph in
  the attribute colour with a soft glow; dashed ring.
- **Type line:** VT323, attribute colour, a 1 px attribute-colour rule.
- **Rules:** Inter, `#D9D0EF`; keyword bold/cyan glow.
- **Stats:** VT323, large: ATK pink, DEF cyan; labels in VT323 at 50%.
- **Footer:** Plex Mono, 4–6 px; `C · CORE` / `OFFER`.
- **Rare/legendary:** rarity dot, subtle holo overlay, stronger rim; never a
  different card geometry.
- **Shimmer:** a low-opacity gold or iridescent sweep over the card; text stays
  on top and readable.
- **Ink:** a rim glow in the ink colour; no text overlay.
- **Back:** black glass, cyan grid, central spark seal, rarity pips/label on
  hover; no bitmap.

### Buttons

- Clipped corner, 1 px cyan border, transparent/near-black fill.
- Primary: cyan fill, void text, outer cyan glow.
- Danger/end: transparent, pink border, pink text.
- Hover: brighter border + small lift/slide; never a bounce.
- Focus: 2 px cyan ring outside the clip; no clipped focus.
- Labels in Orbitron; supporting line in VT323/Plex.

### Score plate / ledgers

- Score plate: black glass, cyan border, pink offset rule, Orbitron kicker,
  giant VT323 number. One per screen; do not stack.
- Ledger: a strip, not a modal. Chips in glass, numbers in VT323, set gauge
  cyan→pink. The cards stay visible and clickable.

## 6. The four-door shell

One bar. Four equal nouns. Same order everywhere:

```text
PLAY    LIBRARY    DECKS    PACKS
```

- Active: cyan text + magenta underline/glow.
- Inactive: `MUTED`; hover -> `INK`.
- Packs carries a small pink badge for unopened packs when relevant.
- No second nav bar, no dropdown, no fifth noun.
- Settings/sound are icon actions on the right, not doors.
- The shell is the same in every room; only the active door changes.

The game stage also carries a local **run strip**: depth/circuit, phase ribbon,
turn, marks, streak, Auto. The global doors never move into that strip.

## 7. Table recipe

Reference: `review/duel-board.html` (Overlap) and `review/index.html#neon`.
Target: the V2 Table screen rebuilt as the Overlap stage.

### Structure

```text
GLOBAL NAV        hidden on the table
SCORE RAIL        YOU · phase ticks · Warden · guard pips · menu
RIBBON (B3)       every face-up effect as text, only below 1280
WARDEN MAT        3 lanes: monster + face-up backrow / set card
SEAM              lit edge for the active side
PLAYER MAT        3 lanes: monster + face-up backrow / set card
HAND              30% shelf: deck strip + card title strips
DOCK              Strike / End Phase / Reset
DRAWER (closed)   Play / Library / Decks / Packs · log · inspect · actions · piles · PIN
```

### Rules

- Two mats, three lanes each, all visible at once. No tabs or hidden lane.
- One 5:7 card, scaled by the window. A face-up spell/trap is a public rule:
  at B1 it takes a full seat next to its monster; at B3 the ribbon states its
  effect. A set card is the only hidden state and never reveals its effect
  through the layout.
- The hand is a 30% shelf, not a fan or a side column. Hover, focus, and click
  lift the full face; click pins it. The deck is the same 30% strip.
- Guard pips and the target bracket carry the rule and the intent. No lane
  numerals, OPEN/CALL/GUARDED, face-sealed chip, intent sentence, or phase names
  on the board.
- The drawer is the only place for the log, inspect, legal-action list, piles,
  and window controls. It opens over the right edge and closes to the menu.
- The log appends; it never rebuilds.
- Legal actions are grouped by card/lane; no 20-button wall.
- The player's focus is the card, the lane, and the number; not the chrome.
- Face attack is sealed while any enemy monster is in a monster zone. The guard
  count is visible, and the state is taught by the UI.

### Table motion

| Beat | Time | What it does |
|---|---:|---|
| Card travel | 220–320 ms | Source → target; no pop at destination |
| Call / Set | 220–260 ms | Lift from hand, slide, settle, ring |
| Flip | 180–240 ms | Edge turns; face settles |
| Attack | 420 ms | Anticipation, arrow, 50–70 ms hit-stop, impact, recoil |
| Damage number | 900 ms | Overshoot 1.18×, settle, fade |
| Destroy | 300–450 ms | Desaturate, crack, slide, residue |
| Phase | 180 ms | Segment warms and sweeps |
| Turn | 220 ms | Edge light shifts; label ticks |
| Auto beat | 650–1200 ms | One consequence at a time; no silent change for 1.2 s |

- **Do not rebuild the board.** Stable actors; rest targets; the director owns
  transitions.
- **Hit-stop only on the impact object**, not the whole room.
- The V2 safety limit applies to shipping: **no table screen shake beyond 2 px**.
  The lab's larger shake is a review exaggeration, not a spec.
- Score plate on a strike; damage plate on a hit; residue always.
- Auto is a broadcast: letterbox, lane spotlight, cue captions, no dead air.

### Implementation notes — X2 Spring Shelf, 2026-11-04

- `src/presentation/table/duel_board_stage.gd` owns the two mats, score rail,
  phase ticks, guard pips, B1/B3 backrow, B3 ribbon, 30% hand shelf, deck strip,
  and target bracket. `board_mode` is `b1` at width ≥1280 and `b3` below; the
  stage computes `card_w`/`card_scale` from the window and never repositions it.
- `src/presentation/table/card_actor.gd` scales one `A` 190 × 266 face to the
  board card. The hand actor's footprint is the 30% shelf while the true 5:7
  face lives inside a clipped container; hover, focus, and selection lift it by
  110% of the card width. The stable hover target covers both the shelf strip
  and the lifted face so the pointer cannot flicker it.
- `src/presentation/table/card_slice.gd` renders the deck's 30% strip from the
  same `CardComposer` back; the count badge sits above it.
- `src/presentation/table/battle_stage.gd` remains the stable actor and animation
  base; `TableScreen` owns the drawer, dock, PIN, and director. The table uses
  150% chrome (82 score, 64 dock, 48 targets, 12–14 labels), a **960 × 720**
  minimum, and fills the window it is given.
- `CardComposer` remains the only face. The 52px tab is a layout constant, not a
  card size. A set card is face-down; a face-up card is public. The hand shelf,
  deck strip, and board cards all keep the true 5:7 geometry.
- `WindowMode` owns fullscreen save/restore; `ViewportFrame` owns the safe rect
  and DPR; `FitPanel` bounds every modal. The shell is a contained 1440×900
  canvas and the table is native. **F11** toggles fullscreen; **F10** shows the
  dev viewport readout.
- The Auto cue is a foreground `CueStrip` above the hand band, not an overlay on
  the lane headers. It may cross a backrow card for a beat; the caption is
  readable, and the card remains clickable. Damage uses the `plate` FX; the lane
  spotlight dims non-focus board actors without dimming the hand.
- Playable hand cards get a thin cyan rim and a top-left dot in manual mode; the
  board stays the hero, so the fan never becomes a second neon field.
- The action dock's STRIKE is a legality-safe shortcut: it uses the selected
  monster's only legal attack, or the only legal attack on the board. Lane
  clicks remain the full manual path.
- The face-sealed rule lives in `DuelRules.legal_actions()` and
  `DuelRules.validate()`. Three pips beside the Warden score show the enemy guard contract;
  the drawer shows the player's own face contract. The UI does not decide it.

## 8. Pack recipe

Reference: `review/packs.html`, full breakdown in
[`../review/PACK_RITUAL.md`](../review/PACK_RITUAL.md).

- Sealed Brass pack; seal is the only primary action.
- Crack: 9-segment line, 12 flecks, 120 ms; dry snap + low thump.
- Flap: 260 ms; mouth glow.
- Deal: 55 ms stagger; cards from the mouth into a fan.
- Tell: pips 1/2/3/4, rarity ring, label. Exact, committed.
- Flip: 470 ms; pinch → turn → paper edge → 60 ms hold → settle.
- Flare: common 120 ms → legendary 900 ms; one active hero.
- Stamp: NEW/×N at 330 ms; wood-block impact.
- Ledger: cards/new/mods-or-reagent/set; fan remains.
- Modes: Ritual, Quick, Auto; skip always to the ledger.
- No room shake. The card recoils; the room stays still.
- No full-screen flash. The legendary bloom is local, one pulse.

## 9. Motion grammar

### Shared timings

| Token | Seconds | Use |
|---|---:|---|
| instant | 0 | reduced mode |
| micro | 0.09 | hover, focus |
| select | 0.14 | lift, tab |
| move | 0.20 | card travel |
| act | 0.24 | call/set/play |
| impact | 0.06 | hit-stop |
| settle | 0.18 | settle after motion |
| panel | 0.20 | panel reveal |
| room | 0.45 | room transition |
| ceremony | 0.70 | stamp/ledger lead-in |

Pack-specific values are in `review/PACK_RITUAL.md`:
press `.08`, crack `.12`, flap `.26`, deal `.26` (+ `.055` stagger), flip `.47`
(anticipation `.08`, pinch `.07`, turn `.11`, hold `.06`, expand `.09`, settle
`.06`), stamp `.18`, summary `.52`, quick flip `.18`, auto gap `.65`.

### Easing rule

**Do not put a global cubic-bezier on a keyframed animation that also uses
offsets.** The timing function maps the whole iteration progress; it will rush
past keyframe offsets and skip the holds. The lab learned this the hard way.

Use:

- `easing: "linear"` globally;
- per-keyframe easing on the first keyframe of each segment;
- offsets for holds and impacts.

This is the difference between a score plate that holds for 620 ms and one that
vanishes before the impact.

### Reduced motion

- All transitions ≤100 ms, no looping pulses, no motes, no rays, no bloom.
- Flip becomes an 80 ms face crossfade; deal becomes a fade at final slots.
- Tells become static pips + label; stamps fade.
- The ledger is immediate and fully populated.
- Focus order and keyboard paths do not change.

## 10. FX grammar

### Table impact

1. **Anticipation:** lift, lean, lane dim, source→target line.
2. **Impact:** 45–70 ms hit-stop; local flash, burst, recoil, shake ≤2 px.
3. **Residue:** drained bar, crack, smoke, open lane, pocketed card, log.

One floating number at a time per target; pool the rest. A number is drawn in
VT323/Plex, oversized, with a dark outline; it never sits over rules text for
long.

### Rarity grammar (pack)

| Rarity | Back tell | Flare | Motes | Extra |
|---|---|---|---:|---|
| Common | 1 pip | 120 ms thin ring | 8 | quiet tick |
| Uncommon | 2 pips | 220 ms ring + ticks | 12 | soft rise |
| Rare | 3 pips triangle | 420 ms dashed rings + rays | 18 | metallic ring |
| Legendary | 4 pips diamond, double ring | 900 ms rings + rays + bloom | 24 | low brass swell, local room shock |

Always pair the colour with the pip count and the word. The legendary banner is
one hero; do not add confetti.

### Forbidden

- full-screen white flash / strobe
- screen shake in the pack or a menu
- full-screen confetti
- slot-machine coin cascades / jackpot arpeggios
- fake near-miss glow
- effects over the card's rules for longer than the beat
- per-frame node creation

## 11. Sound

No music in the pack. The table may have a low ambient bed.

### Cue families

| Cue | Character |
|---|---|
| table draw / move | paper slide, soft tick |
| table call / set | dry card lift, ring |
| table hit | paper snap + low thump + rarity tail |
| table destroy | paper tear + low body |
| table phase / turn | brass tick / soft chime |
| pack press | soft leather/paper |
| pack crack | dry wax snap + 80–120 Hz thump |
| pack flap | paper slide |
| pack deal | rising paper ticks |
| pack tell | 1/2/3/4-note rise; metallic for rare, low swell for legendary |
| pack flip | paper snap |
| pack rare/legendary | metallic ring / low brass swell |
| pack stamp | wood block |
| pack summary | soft chime |
| pack skip | paper whoosh |

- Start the cue on the same frame as the visual; never lead by >30 ms.
- Sound is enhancement: the game must be legible silent.
- Mix: pack SFX around −6 dB; no ducking gymnastics.
- Haptics mobile only: crack 30 ms, flip 10 ms, rare 20 ms, legendary 20+120+20,
  stamp 8 ms.

## 12. Voice and copy

The Warden:

> “The tide remembers every name you drop.”

Keeper lines:

- sealed: “The wax remembers.”
- common: “A quiet cut.”
- uncommon: “The ledger brightens.”
- rare: “A rare cut. Hold it.”
- legendary: “The Unbound answers.”
- summary: “Filed. The set remembers.”

Rules:

- Dry, precise, warm. No “Congratulations!”, “Lucky!”, “You won!”.
- No urgency. No countdown. No purchase CTA in the ceremony.
- Duplicates are income, not failure.
- The tell is a label, not a tease.
- Use semantic keys for localization; do not bake prose into drawing code.

## 13. Reuse

### One renderer

- `CardComposer` is the only card face. The Neon card is a token variant of the
  same six bands, not a new card component.
- `BattleStage` is the only card actor stage. A new room composes the same
  actors; it does not fork them.
- `Tokens.gd` is the only style value source. Theme is data.
- The review labs are reference; the game never imports them.

### Add a new room

1. Compose the four-door shell + a local run/section strip.
2. Reuse the shared panels, buttons, labels, focus, toast, gauges.
3. Use `INK/MUTED` for prose, Orbitron for headings, VT323 for numbers.
4. Add one hero object per screen; give it a material and a light source.
5. Use the shared card/actor components; don't create a second card.
6. Add a keyboard path and a reduced-motion path.
7. Run the layout audit and take 1280/1440/1920 screenshots.
8. Update this document if a token or component changed.

### Add a pack

Use `review/js/pack-data.js` as the data shape reference. A pack is data:

```text
cards[] (key, ownedBefore, ink/shimmer metadata)
reagents[]
newCount, setBefore/setAfter
guarantee, provenance, price, keeper
```

The ceremony is one state machine for all packs. Do not special-case a pack in
the animation.

### Add a table card

Add a content definition, not a script. The card face is generated from
`CardDef`; effects are data. The Neon treatment never branches per card name.

## 14. Godot mapping

| Review reference | Godot target |
|---|---|
| CSS variables in `themes.css` | `Tokens.gd` Neon constants |
| `review.css` shell | `App` + `ThemeBuilder` |
| `board.css` board/lane/card skeleton | `BattleStage`, `TableScreen`, `CardComposer` |
| `board.js` timing / effects | `BattleDirector`, `FxLayer`, `AudioDirector` |
| `pack.css` / `pack.js` | `PackCeremony`, `PackFan`, `PackRevealCard`, `PackFlare` |
| `pack-data.js` | pack content / `PackRoll` result |
| `sound.js` cue names | `AudioDirector` cue contract |
| `review/js/icons.js` glyphs | `SealComposer` / procedural `_draw` glyphs |

### Practical notes

- Use `Color("#46F0FF")`-style constants in `Tokens.gd`; never hard-code a hex in
  a screen.
- Vendor **Orbitron**, **VT323**, **Inter**, **IBM Plex Mono** locally in
  `assets/fonts` and record licenses. The labs use Google Fonts for convenience;
  the game must not depend on the network.
- Godot `StyleBoxFlat` gives borders/radius; for clipped corners use a drawn
  polygon or a custom `StyleBox`/`Control._draw`, not a CSS `clip-path`.
- Cards: keep the V2 `CardComposer` bands and use font/colour tokens. Do not
  rewrite card geometry in a screen.
- Stable actor identity by `DuelCard.uid`; rest targets; no rebuild.
- FX in a `CanvasLayer`; pool numbers/rings; no per-frame node creation.
- Hit-stop on the impact object; not the whole scene.
- Reduced motion via a real setting; the ceremony uses 80–100 ms crossfades.
- The face-sealed rule lives in `DuelRules`, not the UI. The UI displays the
  guard count and the consequence.

## 15. Step-by-step recreation

1. **Foundation**
   - Add the Neon tokens to `Tokens.gd`.
   - Set the default clear colour/background, grid, scanlines, grain.
   - Build the four-door shell; route stubs; focus and hover states.
2. **Card**
   - Keep the V2 5:7 six-band composer.
   - Apply dark-glass face, attribute border, seal grid, Orbitron name, VT323
     stats, Inter rules, footer.
   - Add rarity dot, holo/ink variants. Test 100/150/196/300 px.
3. **Table**
   - Compose the score rail, two mats, B1/B3 backrow, 30% shelf, dock, drawer.
   - Build stable actors, rest positions, event director.
   - Add intent, log, guards, score plate, residue.
   - Add Auto broadcast and the 1.2 s cadence budget.
   - Enforce face-sealed in rules; add tests.
4. **Pack**
   - Build sealed envelope + seal; crack/flap/deal.
   - Fan + tells + flip + flare + stamps.
   - Ledger + modes + skip + zoom.
   - Reuse the card composer and tokens.
5. **Other rooms**
   - Library, Decks, Press with the same shell/panels/buttons.
   - No new visual language; one hero per screen.
6. **Proof**
   - 1280/1440/1920 screenshots; 390 where the screen is meant to be used.
   - Reduced motion, sound off, keyboard, focus.
   - Domain suite, layout audit, seeded duels, fps.
7. **Record**
   - Update this doc and `PLAN.md` with what changed.

## 16. Do / Don't

| Do | Don't |
|---|---|
| Give each screen one hero object and one event light | Light every border and number |
| Use cyan for system, pink for event, amber for numbers | Use pink as the body text or background |
| Use Orbitron for labels, Inter for rules, VT323 for numbers | Set paragraphs in Orbitron/VT323 |
| Keep cards 5:7 and six bands | Stretch, crop, or fork the card face |
| Let cards travel from source to destination | Fade a card in at its destination |
| Use a held frame before impact | Add more animation to make a hit louder |
| Make Auto a broadcast with one beat at a time | Ticker a spreadsheet of actions |
| Make the tell exact, with pips + label | Tease a rarity the card does not have |
| Use paper, wax, wood, brass | Use slot-machine coins/jackpots |
| Keep the fan clickable in the ledger | Replace it with a full-screen modal |
| Add a fourth room as a composition | Add a fifth nav noun |
| Delete the old screen as the new one lands | Keep two visual systems side by side |

## 17. QA checklist

- [ ] 1280 / 1440 / 1920 screenshots; no clipped focus, no overflow.
- [ ] Cards remain 5:7; text fits at the smallest token; audit passes.
- [ ] Four doors present, same order, active state clear.
- [ ] Keyboard path for every action; focus visible; Esc leaves overlays.
- [ ] Reduced motion: no tween >100 ms; no pulse; summary immediate.
- [ ] Sound off: every beat still has a number/mark/movement.
- [ ] No colour-only meaning; pips/labels/glyphs present.
- [ ] No full-screen flash; no room shake in the pack.
- [ ] Hit-stop only on the impact object; ≤2 px table shake in shipping.
- [ ] Auto: max 1.2 s without a visible change.
- [ ] Pack: skip ≤150 ms to a readable ledger; tells exact; stamps from the
  pre-open snapshot.
- [ ] 60 fps at 1440 with the heaviest effect; no per-frame node creation.
- [ ] Domain suite and layout audit pass; seeded duel results recorded.
- [ ] `PLAN.md` and this document are current.

## 18. Source map

| What | Where |
|---|---|
| Neon token block | `review/css/themes.css` → `[data-theme="neon"]` |
| Board skeleton / card base / FX | `review/css/board.css` |
| Pack room / envelope / fan / tells / ledger | `review/css/pack.css` |
| Board interaction / table choreography | `review/js/board.js` |
| Pack ceremony state machine | `review/js/pack.js` |
| Pack content / tell grammar / beats | `review/js/pack-data.js` |
| Procedural cues | `review/js/sound.js` |
| Cards | `review/js/data.js` |
| Pack ceremony handoff | `review/PACK_RITUAL.md` |
| Shipping tokens / type / card geometry | `src/presentation/tokens.gd` |
| Shipping card face | `src/presentation/card/card_composer.gd` |
| Shipping table composition | `src/presentation/table/duel_board_stage.gd` |
| Stable actor / animation base | `src/presentation/table/battle_stage.gd` |
| Shipping FX / plates | `src/presentation/table/fx_layer.gd` |
| Shipping Auto cue | `src/presentation/table/cue_strip.gd` |
| Four-door shell | `src/presentation/shell/top_nav.gd` |
| This contract | `docs/STYLE_NEON_RELIQUARY.md` |
| Phases and gates | `docs/PLAN.md` |
| Working loop | `docs/WORKFLOW.md` |

## 19. Starter tokens

Copy these values into the first Neon token pass. Keep them in one place; do not
sprinkle hex values through screens.

```css
/* canonical Neon core — extend, do not fork */
[data-theme="neon"] {
  --bg: #06030D;
  --panel: #0D071E;
  --panel-2: #0E0822;
  --ink: #F4ECFF;
  --muted: #9C8FBE;
  --faint: #6E638C;
  --line: rgba(70, 240, 255, 0.16);
  --accent: #46F0FF;
  --accent-soft: rgba(70, 240, 255, 0.20);
  --accent-2: #FF3FA4;
  --amber: #FFCC55;
  --good: #7DFFB2;
  --purple: #B06BFF;
  --danger: #FF3FA4;
  --card-face: #0D0820;
  --card-ink: #F4ECFF;
  --card-rules: #D9D0EF;
  --font-display: "Orbitron", sans-serif;
  --font-data: "VT323", monospace;
  --font-rules: "Inter", sans-serif;
  --font-label: "IBM Plex Mono", monospace;
  --nav-radius: 0;
  --clipped-corner: 0.55cqw;
  --hit-stop: 0.06s;
}
```

```gdscript
# src/presentation/tokens.gd — proposed Neon block
class_name Tokens
extends RefCounted

const NEON := {
    "void": Color("#06030D"),
    "panel": Color("#0D071E"),
    "panel_2": Color("#0E0822"),
    "ink": Color("#F4ECFF"),
    "muted": Color("#9C8FBE"),
    "faint": Color("#6E638C"),
    "cyan": Color("#46F0FF"),
    "cyan_soft": Color(0.274, 0.941, 1.0, 0.20),
    "pink": Color("#FF3FA4"),
    "amber": Color("#FFCC55"),
    "green": Color("#7DFFB2"),
    "purple": Color("#B06BFF"),
    "common": Color("#9AA0B5"),
    "uncommon": Color("#7DFFB2"),
    "rare": Color("#FFCC55"),
    "legendary": Color("#FF3FA4"),
}

const NEON_MOTION := {
    "micro": 0.09,
    "select": 0.14,
    "move": 0.20,
    "act": 0.24,
    "hit_stop": 0.06,
    "settle": 0.18,
    "panel": 0.20,
    "room": 0.45,
    "ceremony": 0.70,
    "pack_flip": 0.47,
    "pack_hold": 0.06,
    "pack_skip": 0.12,
}
```

The practical port order is:

1. `Tokens.gd` — these constants, plus fonts and card tokens.
2. `ThemeBuilder` — controls, focus, panels, buttons.
3. `CardComposer` — apply the Neon material to the existing six bands.
4. `BattleStage` / `BattleDirector` — stable actors and the event beats.
5. `FxLayer` — numbers, plates, rings, motes, residue.
6. `PackCeremony` — the pack ritual on the same tokens.
7. Settings, reduced motion, audio, QA.

If you change a value here, change it in `review/css/themes.css`, `review/` and
the Godot tokens in the same task. One mapping, three places, one review.

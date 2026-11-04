# The Pack Ritual — Neon Reliquary

A review lab for the Folio ceremony. It is built on the same Neon Reliquary
tokens as the chosen table direction, and on the real folio rules: the result is
committed at acquisition, the tell comes from the committed card, skip lands on
the ledger, and duplicates are neutral.

The durable visual contract is
[`../docs/STYLE_NEON_RELIQUARY.md`](../docs/STYLE_NEON_RELIQUARY.md); the build
order is [`../docs/PLAN.md`](../docs/PLAN.md).

**Open:** [`packs.html`](packs.html) · the table review is [`index.html`](index.html).

---

## The shape of the ceremony

```text
SEALED
  └─ click the seal → CRACKING
CRACKING
  └─ flap + light spill → DEALING
DEALING
  └─ five cards rise into a fan → READY
READY
  ├─ click a card → FLIPPING
  ├─ REVEAL ALL → SUMMARY
  ├─ AUTO → FLIPPING loop
  └─ S / SKIP → SUMMARY
FLIPPING
  ├─ 470 ms (190 ms Quick) → READY or SUMMARY
  └─ S / SKIP → SUMMARY
SUMMARY
  ├─ OPEN ANOTHER → SEALED (next folio)
  ├─ RESET DEMO → SEALED (Brass)
  └─ DIRECTIONS → the table review
```

The contents are never chosen by the animation. `pack-data.js` holds the
committed cards, the stamps, the before-owned counts, the set progress, and the
reagent (Salvage). The ceremony only reveals them.

## The three demo folios

| Folio | Cards | Guarantee | What it shows |
|---|---:|---|---|
| **Brass** | 5 | Rare guaranteed | The full arc: two commons, an uncommon, a rare with Gilt, and **Razeah, the Unbound** with Iridescent. |
| **Paper** | 3 | Uncommon guaranteed | The 3-card fan, a faster ritual, and an ink-frost / ink-ember print. |
| **Salvage** | 3 + 1 reagent | Reagent guaranteed | The set completes at 16 / 16 and the summary shows a reagent chip. |

The satchel is a sequence in this lab: finish the top folio, then **OPEN
ANOTHER**. This keeps the set progress (9 → 12 → 14 → 16) coherent. The real
satchel can choose any unopened folio; the ceremony is the same.

## The beats

| Beat | Time | What happens |
|---|---:|---|
| Select | −200 ms | The folio lifts; the seal notices. |
| Press | 0 ms | The seal compresses; a hairline appears. |
| Crack | 80 ms | Nine wax segments and 12 flecks; dry snap + low thump. |
| Flap | 200 ms | The flap folds back; light spills from the mouth. |
| Deal | 320 ms | Cards rise from the mouth with a 55 ms stagger. |
| Tell | hover / focus | Pips, ring, and label; read from the committed card. |
| Flip | 470 ms | Lift → pinch → paper edge → 60 ms hold → face. |
| Flare | 320 ms+ | 120 / 220 / 420 / 900 ms by rarity. |
| Stamp | 330 ms | NEW or ×N slams onto the card. |
| Ledger | last + 250 ms | Counts, set gauge, recent pulls, next action. |

The flip is the same duration at every rarity; only the celebration scales.
Hovering a back is the anticipation beat, and the tell is exact.

## Rarity grammar

| Rarity | Tell | Colour | Flare |
|---|---|---|---|
| Common | 1 pip | grey-cyan | 120 ms, thin ring, 8 motes |
| Uncommon | 2 pips | acid green | 220 ms, ring + ticks, 12 motes |
| Rare | 3 pips in a triangle | amber | 420 ms, dashed rings + rays + sweep |
| Legendary | 4 pips in a diamond, double ring | hot magenta | 900 ms, rings + rays + bloom, local room shock |

Every tell is paired with a **text label** and a pip count. There is no
colour-only signal and no fake near-miss.

## Modes

- **Ritual** — manual; the player turns every card.
- **Quick** — 190 ms flips, compressed flare, same beats.
- **Auto** — the ledger turns the cards, 650 ms apart, and stops at the summary.
  Any manual input cancels auto-advance.

`SKIP` works from the crack onward. It reveals every card and lands on the
ledger; it never exits without showing the result. `REVEAL ALL` is the faster
middle path. `Esc` closes the zoom or theater.

## The ledger

The summary is a strip under the fan, not a modal. The cards stay visible and
clickable.

- Cards, **NEW**, **MODS** (shimmer + ink) or **REAGENT**, and Set progress.
- A set gauge that fills from the pre-open count to the post-open count.
- **OPEN ANOTHER** if an unopened folio remains; otherwise **RESET DEMO** and
  **DIRECTIONS**.
- Recent pulls stay in the left rail.
- The fan dims and shifts up; clicking a card opens the inspect zoom.

## Ethical guardrails

1. The result is committed before the first frame.
2. The tell is derived from the committed rarity.
3. No reroll, no paid re-open, no urgency, no purchase CTA in the ceremony.
4. Skip is available from the crack onward and lands on the ledger.
5. `×N` is neutral; duplicates are income, not failure.
6. No full-screen flash, no screen shake, no casino confetti, no slot-machine
   audio. Wax, paper, wood, brass; local card motion only.
7. Reduced motion removes the motion but keeps the pips, labels, stamps, and
   summary.

## Files

```text
packs.html              the review page + annotation sections
css/pack.css            shell, satchel room, envelope, fan, tells, flares, ledger
js/pack-data.js         the three folios, tell grammar, beats, reject list
js/pack.js              ceremony state machine, FX, modes, zoom, ratings, notes
```

Reuses:

- `js/data.js` for card definitions (now includes the full 16-card core set)
- `js/board.js` for `cardMarkup()` and `backMarkup()` — no forked card face
- `css/themes.css` for the Neon Reliquary tokens
- `js/sound.js` for the procedural folio cues

## Adding a pack

Add a record to `RAZEAH_PACKS.folios` in `pack-data.js`:

```js
{
  id: "folio.example",
  no: "04",
  name: "Vault Folio",
  short: "Vault",
  cardsCount: 5,
  guarantee: "Rare guaranteed",
  provenance: 50,
  price: 750,
  shimmerChance: "10%",
  keeper: "...",
  newCount: 2,
  setBefore: 16,
  setAfter: 16,
  reagents: [],
  cards: [
    { key: "ashMoth", ownedBefore: 0 },
    { key: "tidecall", ownedBefore: 2 },
    // ...
  ]
}
```

- `ownedBefore` is the pre-open count for that definition.
- `newCount` / `setBefore` / `setAfter` feed the ledger.
- `shimmer` / `ink` are display metadata; the card face and the tell are derived
  from the card definition and the pack record.

## Godot mapping

| Review | Godot |
|---|---|
| `pack.js` state machine | new `FolioCeremony` (`SEALED → CRACKING → DEALING → READY → FLIPPING → SUMMARY`) |
| `packs.html` room | `FolioScreen` rebuilt around stable nodes; no stage rebuild on crack |
| Envelope markup | `envelope_art.gd` with `crack_progress`, `flap_progress`, `mouth_glow`, flecks |
| Card slots / flip | `FolioRevealCard` + `FolioFan`; pinched turn, paper edge, hit-stop |
| Tell pips / ring | same card back composition; pips 1/2/3/4, rarity label |
| Aura / rays / motes | new `FolioFlare` renderer pooled per card |
| Summary strip | `FolioScreen` ledger; the fan stays alive |
| Cue sheet | new `FolioAudio`; silent fallback keeps the timing |
| Neon tokens | `Tokens.gd` + `ThemeBuilder` scoped to the Folio room |

The target is the same as the spec: **one `FolioCeremony`, stable actors, one
renderer, no rebuild between beats.** This lab is the visual/timing target for
that implementation.

## Verification

Exercised in Chromium at 1440×1000 and 390×844, and from `file://`:

- sealed → crack → fan → tell → common / rare / legendary flips
- NEW / ×N stamps, banner, flare, zoom, skip, reveal all, auto, quick
- 3-card and 5-card fans; Brass → Paper → Salvage; set 9 → 16 / 16
- open another, reset demo, theater open/close, sound sync, reduced motion
- ratings, notes, copy feedback, localStorage
- no console errors; no page-level horizontal overflow

# Razeah V3 — Documentation

The working documents for the rework live here. The rulebook and content are
still owned by V2; V3 is where the new presentation is built.

## Start here

| Document | Use it for |
|---|---|
| [`WORKFLOW.md`](WORKFLOW.md) | How we move from a brief to a reviewed lab, and from a locked lab to a Godot implementation. |
| [`BUILD_STRATEGY.md`](BUILD_STRATEGY.md) | The code-level migration route: strangler port, token compatibility, shell, shared components, room order. |
| [`PLAN.md`](PLAN.md) | The current state, the locked decisions, the phase order, and the acceptance gates. |
| [`STYLE_NEON_RELIQUARY.md`](STYLE_NEON_RELIQUARY.md) | The complete visual, motion, FX, and sound recipe for the chosen Neon Reliquary direction. |

## Current status

- **Rules, content, economy, save:** V2 at `../../RazeahCardsV2` is the source
  of truth. V3 carries the working baseline and the Neon presentation.
- **Table direction:** **Neon Reliquary** is chosen and implemented through the
  table composition.
  Reference: [`../review/index.html#neon`](../review/index.html#neon).
- **Pack ritual:** reviewed and approved; Godot port is next.
  Reference: [`../review/packs.html`](../review/packs.html).
- **Scale / corner contract:** resolved. **X2 Spring Shelf** is ported to the
  Table: a full-window table at **150% chrome** (48px targets, 12–14px labels,
  82px score, 64px dock), a dynamic 5:7 card (167–399px across the supported
  windows), **B1 Front Row at ≥1280** and **B3 Effect Ribbon below 1280**, a
  **30% hand shelf** with hover/focus/click lift and click pin, and a deck strip
  with its count. Set cards stay face-down; face-up spells/traps are public.
  The minimum window is **960 × 720**; the table keeps its current position and
  fills the window it is given. The top nav hides, and the drawer carries the
  four doors.
  Reference: [`../review/x2-backrow.html`](../review/x2-backrow.html),
  [`../review/s3-larger.html`](../review/s3-larger.html), and
  [`../review/accessible.html`](../review/accessible.html). The review labs use
  actual `CardComposer` renders from `review/assets/cards/`, not a CSS card
  imitation; regenerate with `tools/export_review_cards.tscn`.
- **Current gate:** X2 manual/Auto QA (including 1280/1440/1920/2560 and
  1000/960) and reduced motion in [`PLAN.md`](PLAN.md), then port the Folio
  ceremony.
- **Evidence:** 412 tests pass; layout audit passes at nine sizes; the X2 table
  renders B1/B3 with a 30% shelf and public face-up backrow at 1280–2560 and
  1000/960; the face-sealed rule is enforced and the seeded-duel shift is
  recorded.

## The review labs are reference, not shipping code

`review/` is intentionally static HTML/CSS/JS. Its job is to answer visual and
interaction questions quickly. The Godot implementation never imports it.

The labs become the visual contract:

- `review/css/themes.css` → Neon token values.
- `review/css/board.css` → board skeleton, card anatomy, FX vocabulary.
- `review/css/pack.css` → the Folio room, envelope, fan, tells, ledger.
- `review/js/board.js` → interaction and event choreography reference.
- `review/js/pack.js` → `FolioCeremony` state machine reference.
- `review/js/sound.js` → the procedural cue palette.

## External references

- V2 architecture: `../../RazeahCardsV2/docs/ARCHITECTURE.md`
- V2 UI/UX pass: `../../RazeahCardsV2/docs/UI_UX_SPEC.md`
- V2 content/effect DSL: `../../RazeahCardsV2/docs/CONTENT.md`
- V2 folio ceremony research: `../../RazeahCardsV2/docs/FOLIO_PACK_OPENING_SPEC.md`
- V2 roadmap: `../../RazeahCardsV2/docs/ROADMAP.md`
- The working V2 build: `../../RazeahCardsV2`

# Workflow

The repeatable loop for the Razeah V3 rework. The short version:

> **Review in the lab. Lock the decision. Port the tokens and components. Prove
> it in Godot. Update the docs in the same change.**

## 1. Source of truth

| Area | Owner |
|---|---|
| Rules, content, economy, save shape, effect DSL | `../../RazeahCardsV2` |
| Chosen visual language | `docs/STYLE_NEON_RELIQUARY.md` |
| Direction/pack review labs | `review/` |
| Phase order and acceptance gates | `docs/PLAN.md` |
| Current implementation | V3 `src/` (once Phase 0 begins) |

If V2's spec and a V3 presentation idea disagree, the spec wins. If V2's spec is
silent, the locked style guide decides. Do not silently invent a rule in the UI.

## 2. The loop

### Step 1 — Brief

Write the outcome in one paragraph before building.

- What is the player supposed to **feel** or **understand**?
- What is explicitly out of scope?
- What content/rules does it touch?
- What is the reference: a V2 screen, a lab, a pack reference, a single beat?
- What is the acceptance evidence: a screenshot, a test, a timing, a keyboard
  path, a seeded duel result?

If the brief is only a style adjective ("make it cooler"), it is not ready.

### Step 2 — Lab

Build the idea in `review/` first when the question is visual or interactive.

Labs are:

- static HTML/CSS/JS, no build step, `file://`-compatible;
- data-driven (content, packs, beats, tokens in data files);
- themeable through one renderer, not one-off pages;
- reviewed at **1440×900 reference** plus 1280 and 1920;
- tested with sound on and off, motion full and reduced.

A lab is not a prototype of the final architecture. It is a **question made
visible**. Do not spend time on save data, networking, or content pipelines in
a lab.

### Step 3 — Lock

A lab becomes a contract only when it is explicitly chosen.

The lock records:

- the chosen direction and the rejected alternatives (one line of reasoning
  each);
- the token values that will be ported;
- the component list that will be reused;
- the timing constants;
- what the lab deliberately does not cover.

Update [`PLAN.md`](PLAN.md) and
[`STYLE_NEON_RELIQUARY.md`](STYLE_NEON_RELIQUARY.md) in the same change. A lab
without a lock is not allowed to leak into the game.

### Step 4 — Port in layers

Never port a screen by copying a whole lab into the engine. Use this order:

1. **Tokens** — palette, type, spacing, card geometry, motion constants.
2. **Shared chrome** — four-door nav, run strip, panels, buttons, labels.
3. **Card composer** — keep the existing 5:7 six-band anatomy; restyle it from
   tokens. Do not fork the card face.
4. **Screen structure** — stable containers and hit areas. No rebuild of the
   board on every state change.
5. **State and interaction** — legal actions, manual/suggest/auto, keyboard.
6. **Choreography** — entry/exit, source→target, hit-stop, residue.
7. **FX and audio** — event-driven; silent fallback; reduced-motion path.
8. **Tests and evidence** — domain suite, layout audit, seeded duels, screenshots.

A phase is not done when the screenshot matches. It is done when the interaction,
the failure states, the keyboard path, the reduced-motion path, and the tests
all match the contract.

### Step 5 — Prove

Every visual phase needs:

- **1440×900** reference screenshots, plus 1280 and 1920.
- A **reduced-motion** pass: no tween longer than 100 ms, no looping pulse.
- A **keyboard path** for every action; focus is visible and never clipped.
- **Sound off** must still communicate every beat; sound is enhancement.
- No console errors / no GDScript errors.
- The existing domain tests still pass.
- For the table: the seeded duel suite and the 8–12 turn / 65–75% target.
- For the pack: the skip-to-ledger timing and the exact-tell checks.

If a check is not run, say so in the handoff. Do not call it verified.

### Step 6 — Document

The change is not finished until:

- `PLAN.md` status is updated;
- the locked style guide is updated if a token, timing, or component changed;
- the relevant lab is updated if the game implementation exposes a better
  version of the reference;
- `README` links still work;
- a shortcut is recorded with its upgrade point.

Stale docs are a defect.

## 3. Change classes

Classify the change before starting.

| Class | Examples | Required evidence |
|---|---|---|
| **Look** | palette, type, material, ornament | lab screenshot + token diff |
| **Interaction** | hover, flip, lane targeting, keyboard | timed capture + manual checklist |
| **Feel/FX** | hit-stop, flare, camera shake policy, audio cue | before/after capture + reduced-motion |
| **Rules** | face-sealed, legal actions, AI choice | domain tests + seeded duels + UI cue |
| **Content** | card text, Warden voice, pack contents | content validation + card-fit audit |
| **Architecture** | stable actors, ceremony state machine, routes | tests + no-rebuild audit |
| **Scope** | new screen, new pack type, new mode | plan update first |

Rules and content never change as a side effect of a visual port. If a visual
idea needs a rule change, stop and write it as a separate rules decision.

## 4. Review protocol

When reviewing a lab, be specific per beat, not in adjectives.

Useful feedback:

- "The crack holds too long; I want the first flippable card sooner."
- "The tell is readable, but the label is too small at 1280."
- "The legendary flare is right; the common is too quiet."
- "The ledger feels like a modal; keep the fan interactive."
- "This colour is doing too much; make the only hero the card."

Not useful:

- "Make it pop."
- "More juice."
- "I don't like it." (without saying which beat)

The labs include rating chips and notes. Use them, then copy the summary into
the chat. Review **one variable at a time**: pacing, then tell, then flip, then
flare, then ledger.

## 5. Where things live

```text
RazeahCardsV3/
  README.md                 project entry point
  docs/                     this folder: workflow, plan, style contract
  review/                   static review labs (not imported by Godot)
    index.html              table direction review
    packs.html              pack ritual review
    css/ js/                lab implementation
  assets/ content/ src/     added in Phase 0 from V2
```

When the Godot baseline lands:

- Add `review/.gdignore` and `docs/.gdignore` so Godot does not import the labs.
- Keep `content/data.json` generated; never hand-edit it.
- `src/domain` stays pure GDScript.
- `src/application` owns services, save, autoloads.
- `src/presentation` is the only place visual code lives.
- `src/presentation/tokens.gd` is the only place style values live.
- `src/presentation/card/card_composer.gd` is the only place card geometry
  lives.

## 6. Definition of done

A phase is done when all of these are true:

- The outcome from the brief is observable without explanation.
- The four doors still say **Play / Library / Decks / Packs**; no fifth noun.
- Cards are still 5:7 with fixed anatomy.
- Every action has pointer and keyboard paths.
- Every action has a visible or audible consequence; no silent state changes.
- Reduced motion keeps the information and removes the movement.
- Nothing relies on colour alone.
- The domain suite passes; the evidence is attached or linked.
- `PLAN.md` and the style guide are current.
- No new bitmap art, no portraits, no painted backgrounds.
- No fake near-miss, reroll, urgency, or casino feedback.

## 7. Shortcuts

A shortcut is allowed only when it is explicit:

```text
shortcut: JSON save instead of SQLite
why now: persistence is not the phase being proven
upgrade when: persistence milestone, before the save matrix
```

Record it in the plan or the implementation file. An undocumented shortcut is a
bug.

## 8. Handoff format

When handing work back, write four lines:

1. **Proposed** — what was designed but not built.
2. **Implemented** — what actually changed.
3. **Verified** — what was run and where (tests, viewports, `file://`).
4. **Not checked / next** — the honest gap.

This keeps the continuation honest and makes the next session fast.

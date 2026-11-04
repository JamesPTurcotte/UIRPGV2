/* The pack ritual's content. Every result is committed before the envelope is
 * opened; the ceremony only reveals what is already inside.
 */
(function () {
  "use strict";

  var FOLIOS = [
    {
      id: "folio.brass",
      no: "01",
      name: "Brass Folio",
      short: "Brass",
      tagline: "The one you save for.",
      cardsCount: 5,
      guarantee: "Rare guaranteed",
      provenance: 25,
      price: 400,
      shimmerChance: "5%",
      seed: "neon-brass-01",
      keeper: "The Unbound answers.",
      newCount: 3,
      setBefore: 9,
      setAfter: 12,
      reagents: [],
      cards: [
        { key: "ashMoth", ownedBefore: 0 },
        { key: "emberScout", ownedBefore: 2 },
        { key: "tideboundArchivist", ownedBefore: 1, ink: "ink.frost" },
        { key: "verdantColossus", ownedBefore: 0, shimmer: "shimmer.gilt" },
        { key: "razeahUnbound", ownedBefore: 0, shimmer: "shimmer.iridescent" }
      ]
    },
    {
      id: "folio.paper",
      no: "02",
      name: "Paper Folio",
      short: "Paper",
      tagline: "Three cuts. No ceremony tax.",
      cardsCount: 3,
      guarantee: "Uncommon guaranteed",
      provenance: 5,
      price: 120,
      shimmerChance: "2%",
      seed: "neon-paper-02",
      keeper: "The ledger brightens.",
      newCount: 2,
      setBefore: 12,
      setAfter: 14,
      reagents: [],
      cards: [
        { key: "paperWarden", ownedBefore: 0 },
        { key: "tidecall", ownedBefore: 1 },
        { key: "ninefoldSeal", ownedBefore: 0, ink: "ink.ember" }
      ]
    },
    {
      id: "folio.salvage",
      no: "03",
      name: "Salvage Cache",
      short: "Salvage",
      tagline: "The sea returns what it kept.",
      cardsCount: 3,
      guarantee: "Reagent guaranteed",
      provenance: 1,
      price: 0,
      shimmerChance: "0%",
      seed: "neon-salvage-03",
      keeper: "Filed. The set remembers.",
      newCount: 2,
      setBefore: 14,
      setAfter: 16,
      reagents: [{ id: "reagent.pale_ink", name: "Pale Ink", rarity: "common" }],
      cards: [
        { key: "graveWhisper", ownedBefore: 0 },
        { key: "brambleWall", ownedBefore: 1 },
        { key: "hollowLantern", ownedBefore: 0, ink: "ink.dusk" }
      ]
    }
  ];

  var RARITY = {
    common: {
      label: "COMMON",
      pips: 1,
      color: "#9aa0b5",
      dim: "#6f7488",
      note: "One pip. A quiet tick."
    },
    uncommon: {
      label: "UNCOMMON",
      pips: 2,
      color: "#7dffb2",
      dim: "#4e9a70",
      note: "Two pips. A soft rise."
    },
    rare: {
      label: "RARE",
      pips: 3,
      color: "#ffcc55",
      dim: "#b58c2b",
      note: "Three pips in a triangle. The ring has teeth."
    },
    legendary: {
      label: "LEGENDARY",
      pips: 4,
      color: "#ff3fa4",
      dim: "#a52a6d",
      note: "Four pips in a diamond. The room leans in."
    }
  };

  var BEATS = [
    { no: "01", time: "−200 ms", title: "Select", copy: "The folio lifts. The seal notices." },
    { no: "02", time: "0 ms", title: "Press", copy: "The medallion compresses. A hairline appears." },
    { no: "03", time: "80 ms", title: "Crack", copy: "Nine segments of wax split. Flecks, not confetti." },
    { no: "04", time: "200 ms", title: "Flap", copy: "The flap folds back. Light spills from the mouth." },
    { no: "05", time: "320 ms", title: "Deal", copy: "Each card rises from the mouth, 55 ms apart, into a hand." },
    { no: "06", time: "on hover", title: "Tell", copy: "Pips, ring, label. The card is already committed." },
    { no: "07", time: "0–470 ms", title: "Flip", copy: "Pinch, turn, paper edge, a 60 ms hold. Same speed at every rarity." },
    { no: "08", time: "320 ms+", title: "Flare", copy: "Common is a breath. Legendary changes the colour of the room." },
    { no: "09", time: "330 ms", title: "Stamp", copy: "NEW or ×N slams onto the card. Duplicates are neutral." },
    { no: "10", time: "last + 250 ms", title: "Ledger", copy: "Counts, set gauge, recent pulls. The fan stays." }
  ];

  var REJECT = [
    ["Fake near-miss", "The tell is derived from the committed card. A common never gets a legendary ring."],
    ["Rerolls", "The pack is gone on commit. Opening another is a different pack, not a better one."],
    ["Casino confetti", "Paper motes and wax flecks belong. Full-screen confetti hides the card and cheapens it."],
    ["Menu screen shake", "This is a desk, not an impact camera. The card recoils; the room stays still."],
    ["Slot-machine audio", "Paper, wax, wood, brass. No coin cascades, no jackpot arpeggio."],
    ["Urgency", "No countdown, no limited offer, no purchase CTA inside the ceremony."]
  ];

  var RATINGS = [
    ["pacing", "Pacing"],
    ["tell", "The tell"],
    ["flip", "The flip"],
    ["flare", "The flare"],
    ["ledger", "The ledger"]
  ];

  var COPY = {
    heroKicker: "NEON RELIQUARY · FOLIO PROTOCOL 01",
    heroTitle: "Crack the sky.",
    heroLede:
      "A folio is a promise. The wax is the verb. Five cards, one honest tell, and no reroll — the ceremony makes the reveal feel like it cost something.",
    modeNote: "Ritual is manual. Quick compresses the same beats. Auto is opt-in and always stops at the ledger.",
    tellNote:
      "The tell is exact. It is read from the committed card. Every rarity also carries a pip count and a text label, so the signal is never colour alone.",
    ethicsNote:
      "The result is committed before the first frame. Skipping shows the ledger, never leaves the pack. Duplicates are income, not failure. The ceremony is a keeper's ledger, not a slot machine.",
    notesPrompt:
      "What lands? Which beat should be louder, slower, shorter, or gone? Be specific — I will tune the same beats in Godot."
  };

  window.RAZEAH_PACKS = {
    folios: FOLIOS,
    rarity: RARITY,
    beats: BEATS,
    reject: REJECT,
    ratings: RATINGS,
    copy: COPY
  };
})();

/* Razeah front-end review — content and art-direction data.
 * One source for every board. The same cards, Warden, and run state appear in
 * all seven directions; only the skin, motion, and sound change.
 */
(function () {
  "use strict";

  var CARDS = {
    cinderHound: {
      name: "Cinder Hound",
      type: "monster",
      subtype: "Beast",
      attribute: "ember",
      atk: 1200,
      def: 800,
      offer: 0,
      rarity: "common",
      line: "KINDLE: Deal 200 damage.",
      rules: "KINDLE: Deal 200 damage."
    },
    emberScout: {
      name: "Ember Scout",
      type: "monster",
      subtype: "Beast",
      attribute: "ember",
      atk: 1600,
      def: 1000,
      offer: 1,
      rarity: "common",
      line: "FLEET.",
      rules: "FLEET."
    },
    ashMoth: {
      name: "Ash Moth",
      type: "monster",
      subtype: "Beast",
      attribute: "ember",
      atk: 600,
      def: 400,
      offer: 0,
      rarity: "common",
      line: "ECHO: Deal 100 damage.",
      rules: "ECHO: Deal 100 damage."
    },
    tidecall: {
      name: "Tidecall",
      type: "spell",
      subtype: "Normal",
      attribute: "tide",
      atk: null,
      def: null,
      offer: 0,
      rarity: "uncommon",
      line: "Draw 1. If you control a TIDE monster, draw 1 more.",
      rules: "Draw 1. If you control a TIDE monster, draw 1 more."
    },
    ninefoldSeal: {
      name: "Ninefold Seal",
      type: "trap",
      subtype: "Counter",
      attribute: "neutral",
      atk: null,
      def: null,
      offer: 0,
      rarity: "rare",
      line: "Negate an attack, then banish the attacker.",
      rules: "Negate an attack, then banish the attacker."
    },
    paperWarden: {
      name: "Paper Warden",
      type: "monster",
      subtype: "Construct",
      attribute: "neutral",
      atk: 800,
      def: 2000,
      offer: 0,
      rarity: "common",
      line: "VEIL.",
      rules: "VEIL."
    },
    tideboundArchivist: {
      name: "Tidebound Archivist",
      type: "monster",
      subtype: "Wanderer",
      attribute: "tide",
      atk: 1000,
      def: 1600,
      offer: 0,
      rarity: "uncommon",
      line: "FLIP: Draw 1.",
      rules: "FLIP: Draw 1."
    },
    shadeNinth: {
      name: "Shade of the Ninth",
      type: "monster",
      subtype: "Spirit",
      attribute: "umbra",
      atk: 1800,
      def: 1200,
      offer: 1,
      rarity: "uncommon",
      line: "ECHO: Draw 1.",
      rules: "ECHO: Draw 1."
    },
    brambleWall: {
      name: "Bramble Wall",
      type: "monster",
      subtype: "Construct",
      attribute: "verdant",
      atk: 300,
      def: 2200,
      offer: 0,
      rarity: "common",
      line: "No effect.",
      rules: "No effect."
    },
    verdantColossus: {
      name: "Verdant Colossus",
      type: "monster",
      subtype: "Construct",
      attribute: "verdant",
      atk: 2600,
      def: 2200,
      offer: 2,
      rarity: "rare",
      line: "PIERCE.",
      rules: "PIERCE."
    },
    boneOrchard: {
      name: "Bone Orchard",
      type: "trap",
      subtype: "Continuous",
      attribute: "verdant",
      atk: null,
      def: null,
      offer: 0,
      rarity: "uncommon",
      line: "When a monster is destroyed, summon a 500/500 token.",
      rules: "When a monster is destroyed, summon a 500/500 token."
    },
    quietLedger: {
      name: "The Quiet Ledger",
      type: "spell",
      subtype: "Normal",
      attribute: "neutral",
      atk: null,
      def: null,
      offer: 0,
      rarity: "rare",
      line: "Draw 2. At Dusk, discard 1.",
      rules: "Draw 2. At Dusk, discard 1."
    },
    razeahUnbound: {
      name: "Razeah, the Unbound",
      type: "monster",
      subtype: "Wanderer",
      attribute: "neutral",
      atk: 3000,
      def: 2500,
      offer: 2,
      rarity: "legendary",
      line: "KINDLE: Return 1 card from your Remains to your hand. Once per duel.",
      rules: "KINDLE: Return 1 card from your Remains to your hand. Once per duel."
    },
    graveWhisper: {
      name: "Grave Whisper",
      type: "spell",
      subtype: "Normal",
      attribute: "umbra",
      atk: null,
      def: null,
      offer: 0,
      rarity: "common",
      line: "Return 1 monster from your Remains to your hand.",
      rules: "Return 1 monster from your Remains to your hand."
    },
    hollowLantern: {
      name: "Hollow Lantern",
      type: "spell",
      subtype: "Continuous",
      attribute: "umbra",
      atk: null,
      def: null,
      offer: 0,
      rarity: "uncommon",
      line: "Monsters in this lane gain 200 ATK.",
      rules: "Monsters in this lane gain 200 ATK."
    },
    thornSentinel: {
      name: "Thorn Sentinel",
      type: "monster",
      subtype: "Construct",
      attribute: "verdant",
      atk: 1000,
      def: 1800,
      offer: 1,
      rarity: "common",
      line: "KINDLE: Gain 200 Resolve.",
      rules: "KINDLE: Gain 200 Resolve."
    }
  };

  var NAV = [
    { id: "play", label: "Play", active: true },
    { id: "library", label: "Library" },
    { id: "decks", label: "Decks" },
    { id: "packs", label: "Packs", badge: true }
  ];

  var BOARD = {
    run: {
      depth: 3,
      circuit: 2,
      floor: "The Drowned Nave",
      turn: 7,
      marks: 620,
      streak: 2,
      phase: 3
    },
    phases: ["Dawn", "Draw", "Call", "Actions", "Clash", "Dusk"],
    warden: {
      name: "The Damp Warden",
      honorific: "KEEPER OF THE DROWNED NAVE",
      note: "Hold · no modifier",
      resolve: 3180,
      maxResolve: 4000,
      guards: 3,
      hand: 3,
      deck: 32,
      intent: "Tidecall",
      intentLane: 2,
      intentValue: 1800,
      taunt: "The tide remembers every name you drop."
    },
    player: {
      resolve: 3400,
      maxResolve: 4000,
      deck: 28,
      remains: 2,
      void: 0
    },
    lanes: [
      {
        numeral: "I",
        enemyBack: { card: "ninefoldSeal", facedown: true },
        enemy: { card: "paperWarden" },
        player: { card: "brambleWall" },
        playerBack: { card: "boneOrchard", facedown: true }
      },
      {
        numeral: "II",
        enemyBack: null,
        enemy: { card: "tideboundArchivist" },
        player: { card: "verdantColossus" },
        playerBack: null
      },
      {
        numeral: "III",
        enemyBack: null,
        enemy: { card: "shadeNinth" },
        player: null,
        playerBack: null
      }
    ],
    hand: [
      { card: "cinderHound", playable: true },
      { card: "emberScout" },
      { card: "tidecall" },
      { card: "ninefoldSeal" },
      { card: "ashMoth" }
    ],
    log: [
      { kind: "warden", text: "The Damp Warden sets Ninefold Seal in Lane I." },
      { kind: "you", text: "You call Bramble Wall to Lane I." },
      { kind: "you", text: "Verdant Colossus enters Lane II." },
      { kind: "system", text: "Intent read: TIDECALL → Lane II." }
    ]
  };

  var THEMES = [
    {
      id: "lantern",
      no: "01",
      name: "Lantern &amp; Lacquer",
      short: "Lantern",
      tagline: "The séance table.",
      concept:
        "Keep the jade-and-brass identity, but treat the table as a room: candle smoke, wet lacquer, wax, and a Warden who is genuinely watching. Restraint stays; silence does not.",
      tags: ["Gothic", "Tactile", "Warm dark"],
      risk: "Low",
      build: "Low",
      fit: "Closest to today's build",
      palette: [
        ["Void jade", "#07120F"],
        ["Brass", "#D8B45A"],
        ["Parchment", "#E9DFC7"],
        ["Ember", "#D1603D"],
        ["Verdigris", "#4E9E86"]
      ],
      type: "Cormorant Garamond · Inter · IBM Plex Mono",
      voice: "Dry, courteous, drowned.",
      why: [
        "Everything already in the build gets a material upgrade instead of a replacement.",
        "High contrast between paper cards and lacquer furniture keeps rules readable.",
        "The cheapest way to add atmosphere without changing the game's silhouette."
      ],
      watch: [
        "Ornament can crowd the board; every flourish needs a quiet margin.",
        "Gold on green is low contrast at small sizes. Keep numerals bone-white.",
        "If the motion stays subtle, it still needs idle life: embers, breath, flicker."
      ]
    },
    {
      id: "ink",
      no: "02",
      name: "Ink &amp; Iron",
      short: "Ink &amp; Iron",
      tagline: "A woodcut brawl on butcher paper.",
      concept:
        "Print-shop Razeah. Bone paper, soot ink, vermilion warnings, and cards that look stamped by hand. The Warden is a broadside; every hit is a pressed seal.",
      tags: ["Woodcut", "Letterpress", "Rowdy"],
      risk: "Medium",
      build: "Medium",
      fit: "Biggest tonal swing that stays gothic",
      palette: [
        ["Bone paper", "#E7DCC4"],
        ["Soot", "#17130D"],
        ["Vermilion", "#B23A2B"],
        ["Olive", "#52604E"],
        ["Newsprint", "#CFC3AA"]
      ],
      type: "IM Fell English · Courier Prime",
      voice: "A street preacher with a printing press.",
      why: [
        "Cards feel physical and cheap in the best way: cut paper, heavy ink, hard shadows.",
        "The palette is light, so the table reads at a glance in a dark room.",
        "Stamps, smudges, and misprints are cheap procedural texture with huge character."
      ],
      watch: [
        "Light tables need a deliberate frame or they float in the dark app shell.",
        "Too much grunge hurts legibility. Keep rules boxes clean and high-contrast.",
        "It can read 'comedy' if the writing gets knowing. Play it straight."
      ]
    },
    {
      id: "neon",
      no: "03",
      name: "Neon Reliquary",
      short: "Neon",
      tagline: "An arcade cabinet possessed by a dead god.",
      concept:
        "The Stacks as a forbidden machine: black glass, ion cyan, hot magenta, scanlines, and a Warden that speaks in system interrupts. Maximum dopamine, zero subtlety.",
      tags: ["Arcade", "Neon", "Max volume"],
      risk: "High",
      build: "High",
      fit: "If Razeah is allowed to be playful",
      palette: [
        ["Void glass", "#06030D"],
        ["Ion cyan", "#46F0FF"],
        ["Hot magenta", "#FF3FA4"],
        ["Amber", "#FFCC55"],
        ["Ghost", "#F4ECFF"]
      ],
      type: "Orbitron · VT323 · Inter",
      voice: "A machine that learned cruelty from a card game.",
      why: [
        "The strongest instant dopamine: every action flips a switch, splits the signal, and scores.",
        "Dark glass cards make stats and effects glow; the eye goes exactly where the numbers are.",
        "Perfect fit for an auto-battler audience that expects readable numbers and loud feedback."
      ],
      watch: [
        "Tonal risk: the gothic card game is only one filter away from becoming a different game.",
        "Pixel/techno type needs strict size rules; VT323 is excellent for numbers, poor for rules text.",
        "Scanlines, glitch, and bloom must never touch the card text. Reduce-motion needs a full pass."
      ]
    },
    {
      id: "hearth",
      no: "04",
      name: "Hearth &amp; Hollow",
      short: "Hearth",
      tagline: "A cozy storybook with teeth.",
      concept:
        "Warm cream, moss, terracotta, wobbly ink, and soft light. The horror is in what the Warden says, not in how loud the interface is. This is the campfire version of Razeah.",
      tags: ["Cozy", "Storybook", "Soft"],
      risk: "Medium",
      build: "Medium",
      fit: "If the Stacks should feel like a story",
      palette: [
        ["Hearth cream", "#F3E7CF"],
        ["Moss", "#5C6B4A"],
        ["Terracotta", "#C66A4A"],
        ["Ink brown", "#3A3026"],
        ["Butter", "#E9C46A"]
      ],
      type: "Fraunces · Nunito · IBM Plex Mono",
      voice: "A kind voice explaining why you cannot leave.",
      why: [
        "The most inviting table: easy to sit down at, easy to read, easy to root for.",
        "Hand-drawn borders and soft motion give the game a human author.",
        "Cozy + dread is a proven indie register; the contrast is the character."
      ],
      watch: [
        "Softness can sand off the threat. The Warden needs weight and teeth.",
        "Rounded type at card sizes can smear; rules need a cleaner face.",
        "Watercolor textures must stay procedural, or the no-bitmap-art rule breaks."
      ]
    },
    {
      id: "omen",
      no: "05",
      name: "Gilded Omen",
      short: "Omen",
      tagline: "Tarot salon at the end of the world.",
      concept:
        "Black marble, bone, antique gold, oxblood. Symmetry, sunbursts, and Roman numerals. Every duel feels like a reading; every card is laid, not played.",
      tags: ["Tarot", "Deco", "Prestige"],
      risk: "Medium",
      build: "Medium–high",
      fit: "If the table should feel ceremonial",
      palette: [
        ["Onyx", "#08070A"],
        ["Antique gold", "#C9A227"],
        ["Bone", "#F0E7D6"],
        ["Oxblood", "#6E1F2A"],
        ["Slate", "#2A2A30"]
      ],
      type: "Bodoni Moda · Cinzel · IBM Plex Mono",
      voice: "A curator who has already read your ending.",
      why: [
        "The most 'premium' direction: the table reads as a designed object, not a UI.",
        "Symmetry and strong vertical axes make the 3-lane board feel intentional.",
        "Gold hairlines and bone cards photograph beautifully; strong store-page energy."
      ],
      watch: [
        "Ceremony can become slowness; motion must snap at the impact, then settle.",
        "High-contrast serifs need generous leading at card sizes.",
        "Too much symmetry can feel static. The hand and effects need asymmetry."
      ]
    },
    {
      id: "delve",
      no: "06",
      name: "Deepdelve",
      short: "Delve",
      tagline: "Torchlight on wet stone.",
      concept:
        "The table is a carved slab in a mine. Copper rivets, stone grooves, torchlight, dust. Cards are parchment nailed to rock. A crawl you can feel in your shoulders.",
      tags: ["Dungeon", "Stone", "Adventure"],
      risk: "Low–medium",
      build: "Medium",
      fit: "If the run should feel like a crawl",
      palette: [
        ["Deep stone", "#14140F"],
        ["Torchlight", "#F0A54A"],
        ["Copper", "#B87333"],
        ["Moss", "#7F8C5A"],
        ["Parchment", "#E3D6B8"]
      ],
      type: "Alegreya · Alegreya Sans SC · IBM Plex Mono",
      voice: "A foreman who has lost crews before.",
      why: [
        "Materiality gives the board weight; hits land like they cost something.",
        "Copper + torchlight is a warm, legible dark palette with a different soul from jade.",
        "The Descent metaphor becomes physical: depth, stone, pressure, dust."
      ],
      watch: [
        "Stone texture can turn to mud. Keep the arena darker than the cards.",
        "Rivets and carved borders are easy to overdo; repeat one motif, not five.",
        "Warm light on parchment lowers contrast; test at 1280."
      ]
    },
    {
      id: "riso",
      no: "07",
      name: "Riso Rift",
      short: "Riso",
      tagline: "A photocopied grimoire from 1987.",
      concept:
        "Fluorescent pink, riso blue, black, and cheap paper. Halftones, misregistration, tape, circled numbers. The game looks like a zine someone risked their job to print.",
      tags: ["Risograph", "Zine", "Loud"],
      risk: "High",
      build: "Medium",
      fit: "If the game wants a cult zine identity",
      palette: [
        ["Paper", "#F0ECE3"],
        ["Riso blue", "#0078BF"],
        ["Fluoro pink", "#FF48B0"],
        ["Black", "#161616"],
        ["Yellow", "#FFE800"]
      ],
      type: "Archivo Black · Space Grotesk · Space Mono",
      voice: "A marginal note that knows too much.",
      why: [
        "The most human and memorable: halftone, misprint, and tape read as made by a person.",
        "Bright spot color gives the game a poster identity that stands out in a store feed.",
        "Cheap-print constraints force bold composition and clear hierarchy."
      ],
      watch: [
        "Irony is a trap. The world must stay sincere or the dread evaporates.",
        "Two-ink palettes need a strict hierarchy; everything cannot shout.",
        "Halftone at text sizes destroys legibility. Texture belongs behind text, never on it."
      ]
    }
  ];

  var AUTO_BEATS = [
    { label: "DAWN", title: "Turn 07", detail: "The tide is low.", ms: 800 },
    { label: "CALL", title: "Cinder Hound", detail: "Lane III · monster zone", ms: 1100 },
    { label: "KINDLE", title: "200", detail: "The Damp Warden · Resolve", ms: 1000 },
    { label: "STRIKE", title: "2,600", detail: "Tidebound Archivist · Lane II", ms: 1250 },
    { label: "TIDECALL", title: "1,800", detail: "Verdant Colossus braces", ms: 1250 },
    { label: "DUSK", title: "Turn 08", detail: "No blocks. No mercy.", ms: 1000 }
  ];

  var SPEC = {
    shellNote:
      "The layout is deliberately identical in all seven directions. Judge the skin, the motion, and the voice. Once a direction is chosen, we tune layout inside it.",
    boardNote:
      "Same skeleton: four-tab nav, run strip, Warden strip, three lanes, player rail, intent + log, hand, action dock.",
    sourceNote:
      "Every board, card, and ornament below is generated from one renderer. Theme is a data attribute; components never fork.",
    nav: NAV,
    autoBeats: AUTO_BEATS,
    juice: [
      {
        title: "Hit-stop, then detonation",
        body:
          "Freeze the impact frame for 45–70 ms. Then flash, burst, recoil, and shake. The pause is what makes the hit feel expensive."
      },
      {
        title: "Numbers with an ego",
        body:
          "Damage pops from 0.6× to 1.18×, overshoots, then settles. Source and value appear before the total. No number just fades in."
      },
      {
        title: "Every hit leaves a mark",
        body:
          "Cracks, smoke, drained segments, an open lane, a scorched slot. Residue is the proof that the action happened."
      },
      {
        title: "Auto is a broadcast",
        body:
          "When the machine plays, it becomes a show: letterbox, lane spotlight, beat captions, a crowd of numbers, a clean finish. Never a spreadsheet ticking."
      }
    ]
  };

  window.RAZEAH = {
    nav: NAV,
    cards: CARDS,
    board: BOARD,
    themes: THEMES,
    autoBeats: AUTO_BEATS,
    spec: SPEC
  };
})();

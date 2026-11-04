/* Razeah readability review — card faces, effect demo, pick memory.
   The page is static. No game code is imported. */

const CARDS = {
  cinder: {
    name: "Cinder Hound",
    type: "EMBER · BEAST",
    attr: "ember",
    stats: [2600, 1800, 1],
    rules: "KINDLE. Deal 200 damage to the Warden.",
    rarity: "rare",
    footer: "R · CORE",
  },
  verdant: {
    name: "Bramble Wall",
    type: "VERDANT · CONSTRUCT",
    attr: "verdant",
    stats: [600, 2200, 1],
    rules: "VEIL. The first spell each turn costs 1 less.",
    rarity: "rare",
    footer: "R · CORE",
  },
  ash: {
    name: "Ash Moth",
    type: "EMBER · BEAST",
    attr: "ember",
    stats: [1800, 1200, 1],
    rules: "ECHO. Deal 100 damage to the Warden.",
    rarity: "uncommon",
    footer: "U · CORE",
  },
  paper: {
    name: "Ember Scout",
    type: "EMBER · BEAST",
    attr: "ember",
    stats: [1700, 1200, 1],
    rules: "FLEET. May attack the turn it is called.",
    rarity: "common",
    footer: "C · CORE",
  },
  nine: {
    name: "Ninefold Seal",
    type: "NEUTRAL · RITE",
    attr: "neutral",
    stats: ["—", "—", 2],
    rules: "Negate an attack, then banish the attacker.",
    rarity: "rare",
    footer: "R · CORE",
  },
};

const PREVIEW_IDS = [
  "preview-pocket",
  "preview-broadcast",
  "preview-cardled",
  "preview-desk",
  "preview-corner",
];

const PICK_NOTES = {
  "Pocket Cabinet":
    "Corner-first. One expanded lane, 480 × 720, simplified cards, 54px damage.",
  "Broadcast Strip":
    "Wide overlay. Three lanes stay visible, both rails become one scoreboard and one ticker.",
  "Card-Led":
    "Table-first. No rails, effects land on the card, 56px damage and a 16px effect name.",
  "Duelist's Desk":
    "Full-screen maximal. 148px cards, 14px names, 11px rules, one 72px event number.",
  "Corner HUD":
    "Watcher widget. Active lane, two resolves, one last event, 420 × 480.",
};

const timers = new Map();
let picked = null;

function cardHTML(card, simple) {
  const atk = card.stats[0];
  const def = card.stats[1];
  const offer = card.stats[2];
  return [
    `<article class="card card--${card.attr}${simple ? " is-simple" : ""}" aria-hidden="true">`,
    `<div class="card__top"><span class="card__name">${escapeHTML(card.name)}</span><i class="card__rarity" style="--rarity: var(--${rarityColor(card.rarity)})"></i></div>`,
    `<div class="card__type">${escapeHTML(card.type)}</div>`,
    `<div class="card__seal"></div>`,
    `<div class="card__rules">${escapeHTML(card.rules)}</div>`,
    `<div class="card__stats">`,
    `<span class="atk"><small>ATK</small><b>${escapeHTML(String(atk))}</b></span>`,
    `<span class="def"><small>DEF</small><b>${escapeHTML(String(def))}</b></span>`,
    `<span class="offer"><small>OFR</small><b>${escapeHTML(String(offer))}</b></span>`,
    `</div>`,
    `<div class="card__foot"><span>${escapeHTML(card.footer)}</span><span>100%</span></div>`,
    `</article>`,
  ].join("");
}

function rarityColor(rarity) {
  switch (rarity) {
    case "uncommon":
      return "green";
    case "rare":
      return "amber";
    case "legendary":
      return "pink";
    default:
      return "muted";
  }
}

function escapeHTML(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function mountCards() {
  document.querySelectorAll("[data-card]").forEach((slot) => {
    const card = CARDS[slot.dataset.card];
    if (!card) return;
    const simple = slot.dataset.simple === "true";
    slot.insertAdjacentHTML("afterbegin", cardHTML(card, simple));
  });
  requestAnimationFrame(fitCardNames);
  document.fonts?.ready.then(fitCardNames);
  setTimeout(fitCardNames, 450);
}

function fitCardNames() {
  // The real card face needs the same rule: a long name loses a little size
  // before it is allowed to ellipsize.
  document.querySelectorAll(".card__name").forEach((name) => {
    let size = parseFloat(getComputedStyle(name).fontSize);
    let guard = 0;
    while (name.scrollWidth > name.clientWidth + 1 && size > 7.5 && guard < 30) {
      size -= 0.5;
      name.style.fontSize = `${size}px`;
      guard += 1;
    }
  });
}

function runExchange(id) {
  const preview = document.getElementById(id);
  if (!preview) return;
  const previous = timers.get(id);
  if (previous) clearTimeout(previous);
  preview.classList.remove("is-firing");
  // Force a reflow so the same animation can replay.
  void preview.offsetWidth;
  preview.classList.add("is-firing");
  timers.set(
    id,
    setTimeout(() => {
      preview.classList.remove("is-firing");
      timers.delete(id);
    }, 1950),
  );
}

function runAll() {
  PREVIEW_IDS.forEach(runExchange);
}

function setPick(name) {
  picked = name;
  document.querySelectorAll(".option").forEach((option) => {
    option.classList.toggle("is-picked", option.dataset.option === name);
  });
  document.querySelectorAll("[data-pick]").forEach((button) => {
    const chosen = button.dataset.pick === name;
    button.textContent = chosen ? "Picked ✓" : "Choose this";
    button.setAttribute("aria-pressed", chosen ? "true" : "false");
  });

  const note = PICK_NOTES[name] || "A hybrid. Name the parts you want.";
  const nameNode = document.getElementById("pickName");
  const noteNode = document.getElementById("pickNote");
  if (nameNode) nameNode.textContent = name;
  if (noteNode) noteNode.textContent = note;

  const bar = document.getElementById("pickbar");
  const barName = document.getElementById("pickbarName");
  if (bar && barName) {
    barName.textContent = name;
    bar.hidden = false;
  }
}

function clearPick() {
  picked = null;
  document.querySelectorAll(".option").forEach((option) => option.classList.remove("is-picked"));
  document.querySelectorAll("[data-pick]").forEach((button) => {
    button.textContent = "Choose this";
    button.setAttribute("aria-pressed", "false");
  });
  const nameNode = document.getElementById("pickName");
  const noteNode = document.getElementById("pickNote");
  if (nameNode) nameNode.textContent = "Nothing picked yet";
  if (noteNode) noteNode.textContent = "Pick an option above to hold it here. You can also name a hybrid in your reply.";
  const bar = document.getElementById("pickbar");
  if (bar) bar.hidden = true;
}

async function copyPick(button) {
  if (!picked) {
    flash(button, "Pick one first");
    return;
  }
  const text = `Razeah readability review — pick: ${picked}. ${PICK_NOTES[picked] || ""}`;
  try {
    await navigator.clipboard.writeText(text);
    flash(button, "Copied");
  } catch (_error) {
    const area = document.createElement("textarea");
    area.value = text;
    area.setAttribute("readonly", "");
    area.style.position = "fixed";
    area.style.opacity = "0";
    document.body.appendChild(area);
    area.select();
    try {
      document.execCommand("copy");
      flash(button, "Copied");
    } catch (_fallbackError) {
      flash(button, "Copy failed");
    }
    area.remove();
  }
}

function flash(button, text) {
  if (!button) return;
  const previous = button.textContent;
  button.textContent = text;
  setTimeout(() => {
    button.textContent = previous;
  }, 1400);
}

function wire() {
  mountCards();

  const runButtons = ["runAll", "runAllHero"];
  runButtons.forEach((id) => {
    const button = document.getElementById(id);
    if (button) button.addEventListener("click", runAll);
  });

  document.querySelectorAll("[data-test]").forEach((button) => {
    button.addEventListener("click", () => runExchange(button.dataset.test));
  });

  document.querySelectorAll("[data-pick]").forEach((button) => {
    button.addEventListener("click", () => setPick(button.dataset.pick));
  });

  ["copyPick", "copyPickBottom", "copyPickBar"].forEach((id) => {
    const button = document.getElementById(id);
    if (button) button.addEventListener("click", () => copyPick(button));
  });

  const close = document.getElementById("closePickbar");
  if (close) close.addEventListener("click", clearPick);

  // A quiet first demonstration when the page is ready.
  window.addEventListener("resize", fitCardNames);

  if (!window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
    setTimeout(() => runExchange("preview-pocket"), 900);
  }
}

wire();

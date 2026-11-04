/* Third-pass twin-mat review — card faces, exchange demo, pick memory. */

const CARDS = {
  cinder: { name: "Cinder Hound", asset: "assets/cards/ember_cinder_hound.png" },
  verdant: { name: "Bramble Wall", asset: "assets/cards/verdant_bramble_wall.png" },
  ash: { name: "Ash Moth", asset: "assets/cards/ember_ash_moth.png" },
  paper: { name: "Ember Scout", asset: "assets/cards/ember_ember_scout.png" },
  nine: { name: "Ninefold Seal", asset: "assets/cards/neutral_ninefold_seal.png" },
};

const MAT_IDS = [
  "preview-twin",
  "preview-clash",
  "preview-edge",
  "preview-corner",
  "preview-bench",
  "preview-long",
  "preview-ledger",
  "preview-square",
];

const PICK_NOTES = {
  "Twin Mat": "Default full-screen. Two mats, all three lanes, 190px cards, scores at the table edge.",
  "Clash Rail": "Auto/follow. Two mats, 180px cards, both scores and the last consequence on the center rail.",
  "Table Edge": "Immersive. Two mats, 180px cards, scores and actions printed on the mat borders.",
  "Corner Mat": "Pinned. 640 × 800, all three lanes, 150px cards, scores on the mat borders.",
  "Twin Mat + Corner Mat": "One tabletop language at two sizes: full-screen Twin Mat and pinned Corner Mat.",
  "Side Bench": "Biggest cards. Two mats with the hand on a side ledge; 220px cards, 16px rules.",
  "Long Table": "Two mats side by side, lanes as horizontal rows; 140px cards, 11.5px rules.",
  "Ledger Rail": "A scorekeeper column on the left; 190px cards, scores and last event always visible.",
  "Duel Board": "Square 900 × 900 table; all three lanes, 165px cards, scores in the mat borders.",
};

const timers = new Map();
let picked = null;

function cardHTML(card) {
  return `<img class="card-image" src="${card.asset}" alt="" draggable="false">`;
}

function mountCards() {
  document.querySelectorAll("[data-card]").forEach((slot) => {
    const card = CARDS[slot.dataset.card];
    if (!card) return;
    slot.insertAdjacentHTML("afterbegin", cardHTML(card));
  });
  document.querySelectorAll(".card-back").forEach((back) => {
    back.classList.add("is-render");
    back.innerHTML = '<img class="card-back-image" src="assets/cards/back.png" alt="" draggable="false">';
  });
}

function runOne(id) {
  const preview = document.getElementById(id);
  if (!preview) return;
  const previous = timers.get(id);
  if (previous) clearTimeout(previous);
  preview.classList.remove("is-firing");
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
  MAT_IDS.forEach(runOne);
}

function setPick(name) {
  picked = name;
  document.querySelectorAll(".option").forEach((option) => {
    option.classList.toggle("is-picked", option.dataset.option === name);
  });
  document.querySelectorAll("[data-pick]").forEach((button) => {
    const chosen = button.dataset.pick === name;
    if (button.classList.contains("pick")) {
      button.textContent = chosen ? "Picked ✓" : "Choose this";
    }
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
    if (button.classList.contains("pick")) button.textContent = "Choose this";
    button.setAttribute("aria-pressed", "false");
  });
  const nameNode = document.getElementById("pickName");
  const noteNode = document.getElementById("pickNote");
  if (nameNode) nameNode.textContent = "Nothing picked yet";
  if (noteNode) noteNode.textContent = "Pick a mat or the family. You can also name a hybrid in your reply.";
  const bar = document.getElementById("pickbar");
  if (bar) bar.hidden = true;
}

async function copyPick(button) {
  if (!picked) {
    flash(button, "Pick one first");
    return;
  }
  const text = `Razeah twin-mat review — pick: ${picked}. ${PICK_NOTES[picked] || ""}`;
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

  ["runAll", "runAllHero"].forEach((id) => {
    const button = document.getElementById(id);
    if (button) button.addEventListener("click", runAll);
  });

  document.querySelectorAll("[data-test]").forEach((button) => {
    button.addEventListener("click", () => runOne(button.dataset.test));
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

}

wire();

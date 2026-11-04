/* Duel Board variation lab — card faces, exchange demo, pick memory. */

const CARDS = {
  cinder: { name: "Cinder Hound", asset: "assets/cards/ember_cinder_hound.png" },
  verdant: { name: "Bramble Wall", asset: "assets/cards/verdant_bramble_wall.png" },
  ash: { name: "Ash Moth", asset: "assets/cards/ember_ash_moth.png" },
  paper: { name: "Ember Scout", asset: "assets/cards/ember_ember_scout.png" },
  nine: { name: "Ninefold Seal", asset: "assets/cards/neutral_ninefold_seal.png" },
};

const BOARD_IDS = ["preview-db-grid", "preview-db-overlap", "preview-db-shelf", "preview-db-mirror"];

const PICK_NOTES = {
  "Duel Board — Grid": "900 × 900. Every card 105px; both spell/trap rows fully visible; hand at the bottom.",
  "Duel Board — Overlap": "900 × 900. Every card 145px; spell/trap cards tucked behind monsters; biggest cards.",
  "Duel Board — Shelf": "900 × 900. Every card 120px; full spell/trap rows; hand on a side shelf.",
  "Duel Board — Mirror": "900 × 900. Every card 120px; two mats side by side, each lane a row with monster + spell/trap columns.",
};

const DEFAULT_PICK = "Duel Board — Overlap";
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
  timers.set(id, setTimeout(() => { preview.classList.remove("is-firing"); timers.delete(id); }, 1950));
}

function runAll() {
  BOARD_IDS.forEach(runOne);
}

function setPick(name, announce = true) {
  picked = name;
  document.querySelectorAll(".option").forEach((option) => {
    option.classList.toggle("is-picked", option.dataset.option === name);
  });
  document.querySelectorAll("[data-pick]").forEach((button) => {
    const chosen = button.dataset.pick === name;
    if (button.classList.contains("pick")) button.textContent = chosen ? "Picked ✓" : "Choose this";
    button.setAttribute("aria-pressed", chosen ? "true" : "false");
  });
  const note = PICK_NOTES[name] || "A hybrid. Name the parts you want.";
  const nameNode = document.getElementById("pickName");
  const noteNode = document.getElementById("pickNote");
  if (nameNode) nameNode.textContent = name;
  if (noteNode) noteNode.textContent = note;
  const bar = document.getElementById("pickbar");
  const barName = document.getElementById("pickbarName");
  if (bar && barName) { barName.textContent = name; if (announce) bar.hidden = false; }
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
  if (noteNode) noteNode.textContent = "Pick a Duel Board variant. You can also name a hybrid in your reply.";
  const bar = document.getElementById("pickbar");
  if (bar) bar.hidden = true;
}

async function copyPick(button) {
  if (!picked) { flash(button, "Pick one first"); return; }
  const text = `Razeah Duel Board lab — pick: ${picked}. ${PICK_NOTES[picked] || ""}`;
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
    try { document.execCommand("copy"); flash(button, "Copied"); }
    catch (_fallbackError) { flash(button, "Copy failed"); }
    area.remove();
  }
}

function flash(button, text) {
  if (!button) return;
  const previous = button.textContent;
  button.textContent = text;
  setTimeout(() => { button.textContent = previous; }, 1400);
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
  setPick(DEFAULT_PICK, false);
}

wire();

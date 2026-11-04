/* Side-hand, one-line lab: one window selector drives the three hand variants. */

const SL_PAD = 4;
const SL_SCORE = 82;
const SL_DOCK = 64;
const SL_GAP = 4;
const SL_SEAM = 10;
const SL_MAT_PAD = 26;
const SL_TAB = 52;
const SL_LANE = 26;

const fitToggle = document.getElementById("fitFrames");
const selectedLabel = document.getElementById("fxSelected");
const sizeButtons = [...document.querySelectorAll(".fx-size")];
const frames = [...document.querySelectorAll(".sl-window[data-option]")];

let slWindow = { w: 1920, h: 1080 };

function sideLineCard(w, h) {
  const height = (h - (2 * SL_PAD + SL_SCORE + SL_DOCK + 2 * SL_GAP + SL_MAT_PAD + SL_SEAM)) / 2;
  const width = (w - (2 * SL_PAD + 3 * SL_TAB + 2 * SL_LANE + SL_GAP + 6 + 10)) / 4;
  return Math.max(80, Math.floor(Math.min((height * 5) / 7, width)));
}

function bottomCard(w, h) {
  const height = (h - (2 * SL_PAD + SL_SCORE + SL_DOCK + 3 * SL_GAP + SL_SEAM + SL_MAT_PAD)) / 3;
  const width = (w - (2 * SL_PAD + 2 * SL_LANE + 3 * SL_TAB + 16)) / 3;
  return Math.max(80, Math.floor(Math.min((height * 5) / 7, width)));
}

function cardFor(option, w, h) {
  return option === "s3" ? bottomCard(w, h) : sideLineCard(w, h);
}

function readoutFor(option, w, h, card) {
  const board = 3 * card + 3 * SL_TAB + 2 * SL_LANE;
  const boardH = 2.8 * card + 36;
  if (option === "s3") {
    const hand = 6 * card - 4 * 0.33 * card + 4;
    return {
      win: `${w}×${h}`,
      card: String(card),
      board: String(Math.round(board)),
      use: `${Math.round((Math.max(board, hand) / w) * 100)}% width`,
      heightUse: `${Math.round((boardH / h) * 100)}% board`,
      hand: "bottom",
    };
  }
  return {
    win: `${w}×${h}`,
    card: String(card),
    board: String(Math.round(board)),
    use: `${Math.round(((4 * card + 226) / w) * 100)}% width`,
    heightUse: `${Math.round((boardH / h) * 100)}% board`,
    hand: option === "s1" ? "side fan" : "side scroll",
  };
}

function updateFrame(frame, w, h) {
  const option = frame.dataset.option;
  const card = cardFor(option, w, h);
  frame.style.setProperty("--win-w", `${w}px`);
  frame.style.setProperty("--win-h", `${h}px`);
  frame.style.setProperty("--stage-h", `${h}px`);
  frame.style.setProperty("--card", `${card}px`);

  const article = frame.closest(".fx-option");
  if (!article) return;
  const readout = readoutFor(option, w, h, card);
  const set = (key, value) => {
    article.querySelectorAll(`[data-${key}]`).forEach((node) => {
      node.textContent = value;
    });
  };
  set("win", readout.win);
  set("card", readout.card);
  set("board", readout.board);
  set("use", readout.use);
  set("height-use", readout.heightUse);
  set("hand", readout.hand);
}

function updateAll() {
  frames.forEach((frame) => updateFrame(frame, slWindow.w, slWindow.h));
  if (selectedLabel) selectedLabel.textContent = `${slWindow.w} × ${slWindow.h}`;
  applyFit();
}

function applyFit() {
  const fit = fitToggle?.checked === true;
  document.querySelectorAll(".bg-frame-wrap").forEach((wrap) => {
    const frame = wrap.querySelector(".bg-window");
    if (!frame) return;
    frame.style.transform = "none";
    wrap.style.height = "";
    wrap.classList.remove("is-fit");
    if (!fit) return;
    const available = Math.max(1, wrap.clientWidth - 28);
    const scale = Math.min(1, available / frame.offsetWidth);
    frame.style.transform = `scale(${scale})`;
    frame.style.transformOrigin = "top left";
    wrap.style.height = `${Math.ceil(frame.offsetHeight * scale)}px`;
    wrap.classList.add("is-fit");
  });
}

function selectWindow(w, h) {
  slWindow = { w, h };
  sizeButtons.forEach((button) => {
    const active = Number(button.dataset.w) === w && Number(button.dataset.h) === h;
    button.classList.toggle("is-active", active);
    button.setAttribute("aria-pressed", String(active));
  });
  updateAll();
}

sizeButtons.forEach((button) => {
  button.addEventListener("click", () => {
    selectWindow(Number(button.dataset.w), Number(button.dataset.h));
  });
});

const fanCards = [...document.querySelectorAll(".sl-hand--fan .bg-hand-card")];
const cardNames = {
  "ember_ash_moth.png": "Ash Moth",
  "ember_ember_scout.png": "Ember Scout",
  "neutral_ninefold_seal.png": "Ninefold Seal",
  "ember_cinder_hound.png": "Cinder Hound",
  "verdant_bramble_wall.png": "Bramble Wall",
};

fanCards.forEach((card) => {
  card.tabIndex = 0;
  card.setAttribute("role", "button");
  const image = card.querySelector("img");
  const file = image?.getAttribute("src")?.split("/").pop() || "";
  card.setAttribute("aria-label", `${cardNames[file] || "Hand card"} — lift card`);
  card.setAttribute("aria-pressed", "false");
  card.addEventListener("click", () => {
    const wasOpen = card.classList.contains("is-open");
    fanCards.forEach((other) => {
      other.classList.remove("is-open");
      other.setAttribute("aria-pressed", "false");
    });
    if (!wasOpen) {
      card.classList.add("is-open");
      card.setAttribute("aria-pressed", "true");
    }
  });
  card.addEventListener("keydown", (event) => {
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      card.click();
    }
  });
});

fitToggle?.addEventListener("change", applyFit);
window.addEventListener("resize", () => {
  if (fitToggle?.checked) applyFit();
});

const initiallyActive = sizeButtons.find((button) => button.classList.contains("is-active")) || sizeButtons[0];
if (initiallyActive) {
  selectWindow(Number(initiallyActive.dataset.w), Number(initiallyActive.dataset.h));
}

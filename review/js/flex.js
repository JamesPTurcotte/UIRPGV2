/* Flex lab: one window selector drives four actual-size table options. */

const FX_PAD = 4;
const FX_SCORE = 82;
const FX_DOCK = 64;
const FX_GAP = 4;
const FX_SEAM = 10;
const FX_MAT_PAD = 26;
const FX_TAB = 52;
const FX_LANE = 26;

const fitToggle = document.getElementById("fitFrames");
const selectedLabel = document.getElementById("fxSelected");
const sizeButtons = [...document.querySelectorAll(".fx-size")];
const frames = [...document.querySelectorAll(".fx-window[data-option]")];

let fxWindow = { w: 1920, h: 1080 };

function bottomCard(w, h) {
  const height = (h - (2 * FX_PAD + FX_SCORE + FX_DOCK + 3 * FX_GAP + FX_SEAM + FX_MAT_PAD)) / 3;
  const width = (w - (2 * FX_PAD + 2 * FX_LANE + 3 * FX_TAB + 16)) / 3;
  return Math.max(80, Math.floor(Math.min((height * 5) / 7, width)));
}

function sideCard(w, h) {
  const height = (h - (2 * FX_PAD + FX_SCORE + FX_DOCK + 2 * FX_GAP + FX_MAT_PAD + FX_SEAM)) / 2;
  const width = (w - (2 * FX_PAD + 3 * FX_TAB + 2 * FX_LANE + 2 * FX_GAP + 6 + 10)) / 5;
  return Math.max(80, Math.floor(Math.min((height * 5) / 7, width)));
}

function railWidth(w) {
  if (w < 1200) return 0;
  return Math.min(440, Math.max(260, Math.round(w * 0.18)));
}

function cardFor(option, w, h) {
  if (option === "a") return 190;
  if (option === "c") return sideCard(w, h);
  return bottomCard(w, h);
}

function readoutFor(option, w, h, card) {
  if (option === "a") {
    return {
      win: "1000×1000",
      card: "190",
      board: "900",
      use: "fixed",
      heightUse: "57% board",
      hand: "bottom",
      rail: "—",
    };
  }

  const board = 3 * card + 3 * FX_TAB + 2 * FX_LANE;
  if (option === "b") {
    const hand = 6 * card - 4 * 0.33 * card + 4;
    const used = Math.max(board, hand);
    const boardH = 2.8 * card + 36;
    return {
      win: `${w}×${h}`,
      card: String(card),
      board: String(Math.round(board)),
      use: `${Math.round((used / w) * 100)}% width`,
      heightUse: `${Math.round((boardH / h) * 100)}% board`,
      hand: "bottom",
      rail: "—",
    };
  }
  if (option === "c") {
    const used = board + FX_GAP + (2 * card + 6) + 2 * FX_PAD;
    const boardH = 2.8 * card + 36;
    return {
      win: `${w}×${h}`,
      card: String(card),
      board: String(Math.round(board)),
      use: `${Math.round((used / w) * 100)}% width`,
      heightUse: `${Math.round((boardH / h) * 100)}% board`,
      hand: "side 2-col",
      rail: "—",
    };
  }
  const rail = railWidth(w);
  const boardH = 2.8 * card + 36;
  const hand = 6 * card - 4 * 0.33 * card + 4;
  const used = Math.max(hand, board + (rail > 0 ? rail + FX_GAP : 0));
  return {
    win: `${w}×${h}`,
    card: String(card),
    board: String(Math.round(board)),
    use: `${Math.round((used / w) * 100)}% width`,
    heightUse: `${Math.round((boardH / h) * 100)}% board`,
    hand: "bottom",
    rail: rail > 0 ? `${rail}px` : "collapsed",
  };
}

function updateFrame(frame, w, h) {
  const option = frame.dataset.option;
  if (option === "a") return;
  const card = cardFor(option, w, h);
  const rail = option === "d" ? railWidth(w) : 0;

  frame.style.setProperty("--win-w", `${w}px`);
  frame.style.setProperty("--win-h", `${h}px`);
  frame.style.setProperty("--stage-h", `${h}px`);
  frame.style.setProperty("--card", `${card}px`);
  frame.style.setProperty("--rail-w", `${rail}px`);
  frame.classList.toggle("is-narrow", option === "d" && rail === 0);

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
  set("rail", readout.rail);
}

function updateAll() {
  frames.forEach((frame) => updateFrame(frame, fxWindow.w, fxWindow.h));
  if (selectedLabel) selectedLabel.textContent = `${fxWindow.w} × ${fxWindow.h}`;
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
  fxWindow = { w, h };
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

fitToggle?.addEventListener("change", applyFit);
window.addEventListener("resize", () => {
  if (fitToggle?.checked) applyFit();
});

const initiallyActive = sizeButtons.find((button) => button.classList.contains("is-active")) || sizeButtons[0];
if (initiallyActive) {
  selectWindow(Number(initiallyActive.dataset.w), Number(initiallyActive.dataset.h));
}

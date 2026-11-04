/* Overlap lab controls: view the tucked card, flip its face, and tune the peek.
   The 145px card token is never changed; only the tuck offset is. */

const SET_FACE = "assets/cards/neutral_ninefold_seal.png";
const SET_BACK = "assets/cards/back.png";

const DEFAULTS = {
  top: { peek: 50, face: true },
  side: { spine: 28, face: false },
  angle: { face: true },
  pocket: { face: false },
  "spine-left": { face: false },
  "spine-index": { face: false },
  "spine-hairline": { face: false },
  "spine-corner": { face: false },
  "spine-drawer": { face: false },
};

function laneOf(example) {
  return example.querySelector(".ov-lane");
}

function setOf(example) {
  return example.querySelector(".ov-card--set img");
}

function faceOf(example) {
  return example.dataset.faceUp === "true";
}

function setFace(example, faceUp) {
  const image = setOf(example);
  const button = example.querySelector("[data-face]");
  if (!image || !button) return;
  image.src = faceUp ? SET_FACE : SET_BACK;
  example.dataset.faceUp = faceUp ? "true" : "false";
  button.textContent = faceUp ? "FACE-UP" : "BACK";
  button.setAttribute("aria-pressed", faceUp ? "true" : "false");
  updateState(example);
}

function setLift(example, lifted) {
  const lane = laneOf(example);
  const button = example.querySelector("[data-view]");
  if (!lane || !button) return;
  const drawer = example.dataset.mode === "drawer";
  lane.classList.toggle(drawer ? "is-open" : "is-lifted", lifted);
  button.textContent = lifted ? "Tuck card" : (drawer ? "Slide card out" : "View card behind");
  button.setAttribute("aria-expanded", lifted ? "true" : "false");
  updateState(example);
}

function updateState(example) {
  const key = example.dataset.example;
  const lane = laneOf(example);
  const status = example.querySelector("[data-state]");
  const spec = example.querySelector("[data-spec]");
  if (!lane || !status) return;
  const opened = lane.classList.contains("is-open");
  const lifted = lane.classList.contains("is-lifted") || opened;
  const face = faceOf(example) ? "face shown" : "back shown";
  if (key === "top") {
    const peek = example.querySelector("[data-peek]")?.value || "50";
    if (spec) spec.textContent = `${peek}px`;
    status.textContent = lifted ? `LIFTED · ${face}` : `REST · ${peek}px peek`;
  } else if (key === "side") {
    const spine = example.querySelector("[data-spine]")?.value || "28";
    if (spec) spec.textContent = `${spine}px`;
    status.textContent = lifted ? `LIFTED · ${face}` : `REST · ${spine}px spine`;
  } else if (key === "angle") {
    status.textContent = lifted ? `LIFTED · ${face}` : "REST · click to view";
  } else if (key === "pocket") {
    status.textContent = lifted ? `LIFTED · ${face}` : "REST · hover or click to view";
  } else if (key.startsWith("spine-")) {
    const rest = {
      "spine-left": "REST · left 28px",
      "spine-index": "REST · 44px tab",
      "spine-hairline": "REST · 6px sleeve",
      "spine-corner": "REST · corner tab",
      "spine-drawer": "REST · 12px spine",
    };
    status.textContent = opened ? `OPEN · ${face}` : (lifted ? `LIFTED · ${face}` : rest[key]);
  }
}

function wireExample(example) {
  const key = example.dataset.example;
  const lane = laneOf(example);
  if (!lane) return;

  const image = setOf(example);
  const viewButton = example.querySelector("[data-view]");
  const faceButton = example.querySelector("[data-face]");
  const hotspot = example.querySelector("[data-hotspot]");
  const setCard = example.querySelector("[data-set]");

  setFace(example, !image.src.includes("back.png"));
  setLift(example, false);

  viewButton?.addEventListener("click", () => {
    setLift(example, !lane.classList.contains("is-lifted"));
  });
  faceButton?.addEventListener("click", () => {
    setFace(example, !faceOf(example));
  });
  hotspot?.addEventListener("click", () => {
    setLift(example, !lane.classList.contains("is-lifted"));
  });
  setCard?.addEventListener("click", () => {
    setLift(example, !lane.classList.contains("is-lifted"));
  });

  const peek = example.querySelector("[data-peek]");
  if (peek) {
    peek.addEventListener("input", () => {
      lane.style.setProperty("--peek", `${peek.value}px`);
      const out = example.querySelector(".ov-range output");
      if (out) out.textContent = `${peek.value}px`;
      updateState(example);
    });
  }

  const spine = example.querySelector("[data-spine]");
  if (spine) {
    spine.addEventListener("input", () => {
      lane.style.setProperty("--spine", `${spine.value}px`);
      const out = example.querySelector(".ov-range output");
      if (out) out.textContent = `${spine.value}px`;
      updateState(example);
    });
  }

  example.dataset.exampleKey = key;
}

function resetExamples() {
  document.querySelectorAll(".ov-ex[data-example]").forEach((example) => {
    const key = example.dataset.example;
    const lane = laneOf(example);
    const defaults = DEFAULTS[key] || {};
    if (!lane) return;

    if (defaults.peek) {
      lane.style.setProperty("--peek", `${defaults.peek}px`);
      const peek = example.querySelector("[data-peek]");
      const out = example.querySelector(".ov-range output");
      if (peek) peek.value = String(defaults.peek);
      if (out) out.textContent = `${defaults.peek}px`;
    }
    if (defaults.spine) {
      lane.style.setProperty("--spine", `${defaults.spine}px`);
      const spine = example.querySelector("[data-spine]");
      const out = example.querySelector(".ov-range output");
      if (spine) spine.value = String(defaults.spine);
      if (out) out.textContent = `${defaults.spine}px`;
    }
    setFace(example, defaults.face === true);
    setLift(example, false);
  });

  const spread = document.getElementById("spread-toggle");
  if (spread) spread.checked = false;
}

document.querySelectorAll(".ov-ex[data-example]").forEach(wireExample);
document.getElementById("ovReset")?.addEventListener("click", resetExamples);

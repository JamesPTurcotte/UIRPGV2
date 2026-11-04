/* S3 Larger — fit the 1920 frames, demonstrate the shelf reveal and the lens. */

const fitToggle = document.getElementById("fitFrames");

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

/* The Spring Shelf: the strip lifts to the full card; hover/focus previews,
   click pins. Hover is never the only route. */
const strips = [...document.querySelectorAll(".s3x-strip")];
const stripNames = {
  "ember_ash_moth.png": "Ash Moth",
  "ember_ember_scout.png": "Ember Scout",
  "neutral_ninefold_seal.png": "Ninefold Seal",
  "ember_cinder_hound.png": "Cinder Hound",
  "verdant_bramble_wall.png": "Bramble Wall",
};
strips.forEach((strip) => {
  strip.tabIndex = 0;
  strip.setAttribute("role", "button");
  const image = strip.querySelector("img");
  const file = image?.getAttribute("src")?.split("/").pop() || "";
  strip.setAttribute("aria-label", `${stripNames[file] || "Hand card"} — lift card`);
  strip.setAttribute("aria-pressed", "false");
  strip.addEventListener("click", () => {
    const wasOpen = strip.classList.contains("is-open");
    strips.forEach((other) => {
      other.classList.remove("is-open");
      other.classList.remove("is-peek");
      other.setAttribute("aria-pressed", "false");
    });
    if (!wasOpen) {
      strip.classList.add("is-open");
      strip.setAttribute("aria-pressed", "true");
    }
  });
  strip.addEventListener("keydown", (event) => {
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      strip.click();
    }
  });
});

const shelf = document.querySelector(".s3x-shelf");
if (shelf) {
  const dropStill = () => {
    document.querySelectorAll(".s3x-strip.is-peek").forEach((strip) => strip.classList.remove("is-peek"));
  };
  shelf.addEventListener("mouseenter", dropStill);
  shelf.addEventListener("focusin", dropStill);
}

/* The hand index: clicking a tab changes the full-card lens. */
const lensImg = document.getElementById("s3xLensImg");
const lensName = document.getElementById("s3xLensName");
const tabs = [...document.querySelectorAll(".s3x-tab[data-src]")];
tabs.forEach((tab) => {
  tab.addEventListener("click", () => {
    tabs.forEach((other) => other.classList.toggle("is-active", other === tab));
    if (lensImg) lensImg.src = tab.dataset.src;
    if (lensName) lensName.textContent = tab.dataset.name.toUpperCase();
  });
});

fitToggle?.addEventListener("change", applyFit);
window.addEventListener("resize", () => {
  if (fitToggle?.checked) applyFit();
});
applyFit();

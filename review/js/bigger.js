/* Bigger lab: optional fit-to-pane for the actual-size table frames. */

const fitToggle = document.getElementById("fitFrames");

function applyFit() {
  const fit = fitToggle?.checked === true;
  document.querySelectorAll(".bg-frame-wrap").forEach((wrap) => {
    const frame = wrap.querySelector(".bg-window");
    if (!frame) return;
    if (fit) {
      const available = Math.max(1, wrap.clientWidth - 28);
      const scale = Math.min(1, available / frame.offsetWidth);
      frame.style.transform = `scale(${scale})`;
      frame.style.transformOrigin = "top left";
      wrap.style.height = `${Math.ceil(frame.offsetHeight * scale)}px`;
      wrap.classList.add("is-fit");
    } else {
      frame.style.transform = "none";
      wrap.style.height = "";
      wrap.classList.remove("is-fit");
    }
  });
}

fitToggle?.addEventListener("change", applyFit);
window.addEventListener("resize", () => {
  if (fitToggle?.checked) applyFit();
});

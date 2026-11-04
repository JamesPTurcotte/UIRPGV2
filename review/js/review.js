/* Review shell behaviour: render the seven exhibits, keep the shortlist,
 * persist notes, wire theater mode, and start the autoplay spectacle.
 */
(function () {
  "use strict";

  var D = window.RAZEAH;
  var I = window.RazeahIcons;
  var boards = {};
  var byId = {};
  var openStage = null;
  var toastTimer = null;
  var scrollQueued = false;

  D.themes.forEach(function (theme) {
    byId[theme.id] = theme;
  });

  /* ------------------------------------------------------------------ */
  /* storage                                                             */
  /* ------------------------------------------------------------------ */

  function load(key, fallback) {
    try {
      var raw = localStorage.getItem(key);
      if (!raw) return fallback;
      var parsed = JSON.parse(raw);
      return parsed == null ? fallback : parsed;
    } catch (err) {
      return fallback;
    }
  }

  function save(key, value) {
    try {
      localStorage.setItem(key, JSON.stringify(value));
    } catch (err) {
      /* file:// private mode can reject storage; the review still works. */
    }
  }

  var picks = load("razeah-review-picks", []);
  var notes = load("razeah-review-notes", {});
  if (!Array.isArray(picks)) picks = [];
  picks = picks.filter(function (id) {
    return !!byId[id];
  });
  if (!notes || typeof notes !== "object" || Array.isArray(notes)) notes = {};

  var motion = load("razeah-review-motion", null);
  if (motion !== "reduced" && motion !== "full") {
    motion = window.matchMedia("(prefers-reduced-motion: reduce)").matches ? "reduced" : "full";
  }

  /* ------------------------------------------------------------------ */
  /* helpers                                                             */
  /* ------------------------------------------------------------------ */

  function $(sel, root) {
    return (root || document).querySelector(sel);
  }

  function esc(value) {
    return String(value).replace(/[&<>"']/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c];
    });
  }

  function plain(value) {
    return String(value).replace(/&amp;/g, "&").replace(/<[^>]+>/g, "");
  }

  function swatch(theme) {
    if (theme.id === "ink" || theme.id === "hearth" || theme.id === "riso") {
      return theme.palette[2][1];
    }
    return theme.palette[1][1];
  }

  function showToast(text) {
    var el = $("#siteToast");
    if (!el) return;
    el.textContent = text;
    el.classList.add("is-show");
    clearTimeout(toastTimer);
    toastTimer = setTimeout(function () {
      el.classList.remove("is-show");
    }, 2800);
  }

  function reduceMotion() {
    return motion === "reduced" || document.body.classList.contains("rz-reduce");
  }

  function setMotion(value, announce) {
    motion = value === "reduced" ? "reduced" : "full";
    save("razeah-review-motion", motion);
    document.body.classList.toggle("rz-reduce", motion === "reduced");
    var btn = $("#motionToggle");
    if (btn) {
      btn.textContent = motion === "reduced" ? "Motion: reduced" : "Motion: full";
      btn.setAttribute("aria-pressed", motion === "reduced" ? "true" : "false");
    }
    if (announce) showToast(motion === "reduced" ? "Motion reduced everywhere" : "Full motion restored");
  }

  /* ------------------------------------------------------------------ */
  /* hero fan + index                                                    */
  /* ------------------------------------------------------------------ */

  function buildHeroFan() {
    var fan = $("#heroFan");
    if (!fan) return;
    fan.innerHTML = D.themes
      .map(function (theme, i) {
        var left = 50 + (i - 3) * 8.6;
        var rot = (i - 3) * 6.2;
        var z = 20 - Math.abs(i - 3) * 2;
        return (
          '<div class="hero-card" style="--left:' +
          left +
          "%;--r:" +
          rot +
          "deg;--z:" +
          z +
          '"><div class="rz-skin" data-theme="' +
          theme.id +
          '">' +
          window.RazeahBoard.cardMarkup("cinderHound") +
          "</div></div>"
        );
      })
      .join("");
  }

  function buildIndex() {
    var index = $("#directionIndex");
    if (!index) return;
    index.innerHTML =
      '<div class="direction-index__inner">' +
      D.themes
        .map(function (theme) {
          return (
            '<a class="dir-chip" href="#' +
            theme.id +
            '" data-chip="' +
            theme.id +
            '"><span class="dir-chip__no">' +
            theme.no +
            '</span><span class="dir-chip__swatch" style="--c:' +
            swatch(theme) +
            '"></span><span>' +
            theme.short +
            '</span><span class="dir-chip__star">★</span></a>'
          );
        })
        .join("") +
      "</div>";
  }

  /* ------------------------------------------------------------------ */
  /* directions                                                          */
  /* ------------------------------------------------------------------ */

  function directionHTML(theme) {
    var picked = picks.indexOf(theme.id) > -1;
    var hasNote = !!(notes[theme.id] && notes[theme.id].trim());
    var swatches = theme.palette
      .map(function (p) {
        return (
          '<div class="swatch"><i style="--c:' +
          p[1] +
          '"></i><b>' +
          p[0] +
          "</b><span>" +
          p[1] +
          "</span></div>"
        );
      })
      .join("");
    var tags = theme.tags
      .map(function (t) {
        return "<li>" + t + "</li>";
      })
      .join("");
    var why = theme.why
      .map(function (t) {
        return "<li>" + t + "</li>";
      })
      .join("");
    var watch = theme.watch
      .map(function (t) {
        return "<li>" + t + "</li>";
      })
      .join("");

    return (
      '<article class="direction reveal" id="' +
      theme.id +
      '" data-direction="' +
      theme.id +
      '">' +
      '<header class="direction__head">' +
      '<div class="direction__no">' +
      theme.no +
      "</div>" +
      '<div class="direction__title">' +
      '<p class="eyebrow">DIRECTION ' +
      theme.no +
      " · RISK " +
      theme.risk.toUpperCase() +
      " · BUILD " +
      theme.build.toUpperCase() +
      "</p>" +
      "<h2>" +
      theme.name +
      "</h2>" +
      '<p class="direction__tagline">' +
      theme.tagline +
      "</p>" +
      "</div>" +
      '<div class="direction__tools">' +
      '<button class="pick' +
      (picked ? " is-picked" : "") +
      '" type="button" data-pick="' +
      theme.id +
      '" aria-pressed="' +
      (picked ? "true" : "false") +
      '"><span class="pick__star">' +
      (picked ? "★" : "☆") +
      '</span><span class="pick__label">' +
      (picked ? "Shortlisted" : "Shortlist") +
      "</span></button>" +
      '<button class="note-toggle' +
      (hasNote ? " has-note" : "") +
      '" type="button" data-note-toggle="' +
      theme.id +
      '">Notes</button>' +
      (theme.id === "neon"
        ? '<a class="note-toggle pk-jump" href="packs.html">Pack ritual ↗</a>'
        : "") +
      "</div>" +
      "</header>" +
      '<p class="direction__concept">' +
      theme.concept +
      "</p>" +
      '<div class="stage" id="stage-' +
      theme.id +
      '" data-stage="' +
      theme.id +
      '">' +
      '<div class="stage__chrome">' +
      '<div class="stage__label"><span class="live-dot"></span> LIVE TABLE <span class="stage__hint">AUTO · STRIKE · END TURN · CLICK THE GLOWING CARD</span><span class="stage__scroll">SCROLL BOARD →</span></div>' +
      '<div class="stage__tools">' +
      '<button class="stage__btn theater-open-btn" type="button" data-theater="' +
      theme.id +
      '" aria-expanded="false" aria-controls="stage-' +
      theme.id +
      '">' +
      I.svg("expand") +
      " Expand</button>" +
      '<button class="stage__btn theater-close" type="button" data-theater-close="' +
      theme.id +
      '">' +
      I.svg("close") +
      " Close</button>" +
      "</div>" +
      "</div>" +
      '<div class="stage__board"><div class="rz-mount" data-board="' +
      theme.id +
      '"></div></div>' +
      '<div class="stage__foot"><span><b>Try it:</b> call the glowing Cinder Hound · hit STRIKE · END TURN · or press <b>AUTO</b> for the full broadcast</span><span>1440 × 900 · uniform scale · live</span></div>' +
      "</div>" +
      '<div class="direction__meta">' +
      '<div class="meta">' +
      "<h4>Palette</h4>" +
      '<div class="palette">' +
      swatches +
      "</div>" +
      "<h4>Type &amp; voice</h4>" +
      '<dl class="spec"><dt>Type</dt><dd>' +
      theme.type +
      "</dd><dt>Voice</dt><dd>" +
      theme.voice +
      "</dd><dt>Fit</dt><dd>" +
      theme.fit +
      "</dd></dl>" +
      '<ul class="taglist">' +
      tags +
      "</ul>" +
      "</div>" +
      '<div class="meta"><h4>Why it lands</h4><ul class="list">' +
      why +
      "</ul></div>" +
      '<div class="meta"><h4>Watch out</h4><ul class="list list--quiet">' +
      watch +
      "</ul>" +
      '<div class="note-wrap" data-note-wrap="' +
      theme.id +
      '">' +
      "<h4>Your notes</h4>" +
      '<textarea data-note="' +
      theme.id +
      '" placeholder="What lands? What feels wrong? What would you steal from another direction?"></textarea>' +
      '<div class="note-foot"><span>Saved in this browser</span><span class="note-foot__right"><span class="saved" data-saved="' +
      theme.id +
      '">Saved ✓</span><button class="note-close" type="button" data-note-close="' +
      theme.id +
      '">Hide</button></span></div>' +
      "</div>" +
      "</div>" +
      "</div>" +
      "</article>"
    );
  }

  function buildDirections() {
    var mount = $("#directions");
    if (!mount) return;
    mount.innerHTML = D.themes.map(directionHTML).join("");

    document.querySelectorAll("[data-board]").forEach(function (el) {
      var id = el.getAttribute("data-board");
      boards[id] = window.RazeahBoard.mount(el, id);
    });

    document.querySelectorAll("[data-stage]").forEach(function (stage) {
      var theme = byId[stage.getAttribute("data-stage")];
      if (theme) stage.style.setProperty("--theme-accent", swatch(theme));
    });

    /* Fill textareas after insertion so notes never pass through HTML. */
    Object.keys(notes).forEach(function (id) {
      var area = document.querySelector('[data-note="' + id + '"]');
      if (area) area.value = notes[id];
    });
  }

  /* ------------------------------------------------------------------ */
  /* static content                                                      */
  /* ------------------------------------------------------------------ */

  function buildStatic() {
    var nav = $("#navContract");
    if (nav) {
      nav.innerHTML = D.nav
        .map(function (item) {
          return "<span>" + item.label + "</span>";
        })
        .join("");
    }

    var rack = $("#skinRack");
    if (rack) {
      rack.innerHTML = D.themes
        .map(function (theme) {
          return (
            '<div class="rack-item"><span class="rack-item__no">' +
            theme.no +
            '</span><div class="rz-skin" data-theme="' +
            theme.id +
            '">' +
            window.RazeahBoard.cardMarkup("cinderHound") +
            '</div><span class="rack-item__name">' +
            theme.short +
            "</span></div>"
          );
        })
        .join("");
    }

    var juice = $("#juiceGrid");
    if (juice) {
      juice.innerHTML = D.spec.juice
        .map(function (item, i) {
          return (
            '<article class="juice"><span class="juice__no">0' +
            (i + 1) +
            "</span><h3>" +
            item.title +
            "</h3><p>" +
            item.body +
            "</p></article>"
          );
        })
        .join("");
    }

    var cues = $("#cueList");
    if (cues) {
      cues.innerHTML = D.autoBeats
        .map(function (beat, i) {
          return (
            '<div class="cue"><span class="cue__no">0' +
            (i + 1) +
            '</span><span class="cue__label">' +
            beat.label +
            '</span><span class="cue__title">' +
            beat.title +
            '</span><span class="cue__detail">' +
            beat.detail +
            "</span></div>"
          );
        })
        .join("");
    }
  }

  /* ------------------------------------------------------------------ */
  /* shortlist + notes                                                   */
  /* ------------------------------------------------------------------ */

  function syncPicks() {
    document.querySelectorAll("[data-pick]").forEach(function (btn) {
      var id = btn.getAttribute("data-pick");
      var picked = picks.indexOf(id) > -1;
      btn.classList.toggle("is-picked", picked);
      btn.setAttribute("aria-pressed", picked ? "true" : "false");
      var star = btn.querySelector(".pick__star");
      var label = btn.querySelector(".pick__label");
      if (star) star.textContent = picked ? "★" : "☆";
      if (label) label.textContent = picked ? "Shortlisted" : "Shortlist";
    });

    document.querySelectorAll("[data-chip]").forEach(function (chip) {
      chip.classList.toggle("is-picked", picks.indexOf(chip.getAttribute("data-chip")) > -1);
    });

    renderShortlist();
  }

  function renderShortlist() {
    var box = $("#shortlist");
    if (!box) return;
    var picked = D.themes.filter(function (theme) {
      return picks.indexOf(theme.id) > -1;
    });

    if (!picked.length) {
      box.innerHTML =
        '<div class="shortlist__empty"><b>Nothing shortlisted yet.</b>Star a direction above, or leave notes on the ones you almost picked.</div>';
      return;
    }

    box.innerHTML = picked
      .map(function (theme) {
        var note = notes[theme.id] && notes[theme.id].trim();
        return (
          '<div class="pickrow"><span class="pickrow__no">' +
          theme.no +
          "</span><div><h4>" +
          theme.name +
          "<span>" +
          theme.risk +
          " risk · " +
          theme.build +
          " build</span></h4><p>" +
          (note ? esc(note) : '<span style="opacity:.45">No notes yet — open Notes on the card above.</span>') +
          '</p></div><button type="button" data-unpick="' +
          theme.id +
          '" aria-label="Remove ' +
          esc(plain(theme.name)) +
          ' from shortlist">×</button></div>'
        );
      })
      .join("");
  }

  function togglePick(id) {
    var index = picks.indexOf(id);
    if (index > -1) picks.splice(index, 1);
    else picks.push(id);
    save("razeah-review-picks", picks);
    syncPicks();
    var theme = byId[id];
    showToast(
      index > -1
        ? "Removed " + plain(theme.name) + " from shortlist"
        : "Shortlisted " + plain(theme.name) + " — notes save automatically"
    );
  }

  function setNote(id, value) {
    value = String(value || "");
    if (value.trim()) notes[id] = value;
    else delete notes[id];
    save("razeah-review-notes", notes);
    var toggle = document.querySelector('[data-note-toggle="' + id + '"]');
    if (toggle) toggle.classList.toggle("has-note", !!value.trim());
    var saved = document.querySelector('[data-saved="' + id + '"]');
    if (saved) {
      saved.classList.add("is-on");
      clearTimeout(saved._timer);
      saved._timer = setTimeout(function () {
        saved.classList.remove("is-on");
      }, 900);
    }
    if (picks.indexOf(id) > -1) renderShortlist();
  }

  function toggleNotes(id) {
    var wrap = document.querySelector('[data-note-wrap="' + id + '"]');
    var btn = document.querySelector('[data-note-toggle="' + id + '"]');
    if (!wrap) return;
    var open = wrap.classList.toggle("is-open");
    if (btn) btn.textContent = open ? "Hide notes" : "Notes";
    if (open) {
      var area = wrap.querySelector("textarea");
      setTimeout(function () {
        wrap.scrollIntoView({ behavior: reduceMotion() ? "auto" : "smooth", block: "center" });
        if (area) {
          setTimeout(function () {
            area.focus({ preventScroll: true });
          }, 120);
        }
      }, 50);
    }
  }

  function closeNotes(id) {
    var wrap = document.querySelector('[data-note-wrap="' + id + '"]');
    var btn = document.querySelector('[data-note-toggle="' + id + '"]');
    if (wrap) wrap.classList.remove("is-open");
    if (btn) btn.textContent = "Notes";
  }

  /* ------------------------------------------------------------------ */
  /* theater + autoplay                                                  */
  /* ------------------------------------------------------------------ */

  function openTheater(stage) {
    if (!stage) return;
    if (openStage && openStage !== stage) closeTheater();
    openStage = stage;
    var host = stage.closest(".direction");
    if (host) {
      host.classList.add("is-in", "theater-host");
    }
    stage.classList.add("is-theater");
    document.body.classList.add("theater-open");
    var opener = stage.querySelector("[data-theater]");
    if (opener) opener.setAttribute("aria-expanded", "true");
    var close = stage.querySelector("[data-theater-close]");
    if (close) {
      setTimeout(function () {
        close.focus({ preventScroll: true });
      }, 40);
    }
  }

  function closeTheater() {
    if (!openStage) return;
    var stage = openStage;
    var id = stage.getAttribute("data-stage");
    var ctx = boards[id];
    if (ctx && ctx.state.auto) {
      var autoBtn = stage.querySelector('[data-ref="autoBtn"]');
      if (autoBtn) autoBtn.click();
    }
    stage.classList.remove("is-theater");
    var host = stage.closest(".direction");
    if (host) host.classList.remove("theater-host");
    document.body.classList.remove("theater-open");
    openStage = null;
    var opener = stage.querySelector("[data-theater]");
    if (opener) {
      opener.setAttribute("aria-expanded", "false");
      opener.focus({ preventScroll: true });
    }
  }

  function watchAutoplay() {
    var target = picks.length ? picks[0] : "lantern";
    var stage = document.getElementById("stage-" + target);
    if (!stage) return;
    openTheater(stage);
    var ctx = boards[target];
    if (ctx) {
      window.RazeahBoard.startAuto(ctx);
      showToast("AUTOPLAY · " + plain(byId[target].name) + " · PRESS STOP TO TAKE OVER");
    }
  }

  /* ------------------------------------------------------------------ */
  /* copy                                                                */
  /* ------------------------------------------------------------------ */

  function copyText(text) {
    if (navigator.clipboard && window.isSecureContext) {
      return navigator.clipboard.writeText(text);
    }
    return new Promise(function (resolve, reject) {
      try {
        var ta = document.createElement("textarea");
        ta.value = text;
        ta.setAttribute("readonly", "");
        ta.style.position = "fixed";
        ta.style.left = "-9999px";
        document.body.appendChild(ta);
        ta.select();
        document.execCommand("copy");
        ta.remove();
        resolve();
      } catch (err) {
        reject(err);
      }
    });
  }

  function buildSummary() {
    var lines = ["RAZEAH — FRONT-END DIRECTION REVIEW", ""];
    var picked = D.themes.filter(function (theme) {
      return picks.indexOf(theme.id) > -1;
    });

    if (!picked.length) {
      lines.push("Shortlist: nothing yet.");
    } else {
      lines.push("SHORTLIST");
      picked.forEach(function (theme, i) {
        lines.push(i + 1 + ". " + plain(theme.name) + " — " + plain(theme.tagline));
        var note = notes[theme.id] && notes[theme.id].trim();
        if (note) lines.push("   Notes: " + note.replace(/\n/g, "\n   "));
      });
    }

    var otherNotes = D.themes.filter(function (theme) {
      return notes[theme.id] && notes[theme.id].trim() && picks.indexOf(theme.id) < 0;
    });
    if (otherNotes.length) {
      lines.push("", "OTHER NOTES");
      otherNotes.forEach(function (theme) {
        lines.push(plain(theme.name) + ":");
        lines.push("   " + notes[theme.id].trim().replace(/\n/g, "\n   "));
      });
    }

    lines.push("", "NEXT: pick one direction, then refactor the Godot table into shared tokens + components.");
    return lines.join("\n");
  }

  function copySummary() {
    var text = buildSummary();
    copyText(text)
      .then(function () {
        showToast("Review summary copied · paste it into the chat");
      })
      .catch(function () {
        window.prompt("Copy review summary", text);
      });
  }

  /* ------------------------------------------------------------------ */
  /* scroll state                                                        */
  /* ------------------------------------------------------------------ */

  function updateScrollState() {
    scrollQueued = false;
    var y = window.scrollY + 150;
    var activeDirection = null;

    document.querySelectorAll(".direction").forEach(function (dir) {
      var top = dir.getBoundingClientRect().top + window.scrollY;
      if (top <= y) activeDirection = dir.id;
    });

    var section = "directions";
    ["bones", "feel", "decision"].forEach(function (id) {
      var el = document.getElementById(id);
      if (el && el.getBoundingClientRect().top + window.scrollY <= y) section = id;
    });

    document.querySelectorAll("[data-chip]").forEach(function (chip) {
      chip.classList.toggle(
        "is-active",
        section === "directions" && chip.getAttribute("data-chip") === activeDirection
      );
    });
    document.querySelectorAll(".mastnav a[data-nav]").forEach(function (link) {
      link.classList.toggle("is-active", link.getAttribute("data-nav") === section);
    });

    var doc = document.documentElement;
    var max = doc.scrollHeight - window.innerHeight;
    var progress = max > 0 ? Math.min(1, Math.max(0, window.scrollY / max)) : 0;
    var bar = document.getElementById("scrollProgress");
    if (bar) bar.style.width = (progress * 100).toFixed(2) + "%";
  }

  function queueScrollState() {
    if (scrollQueued) return;
    scrollQueued = true;
    requestAnimationFrame(updateScrollState);
  }

  /* ------------------------------------------------------------------ */
  /* reveal                                                              */
  /* ------------------------------------------------------------------ */

  function buildReveal() {
    var els = document.querySelectorAll(".reveal");
    if (!("IntersectionObserver" in window) || reduceMotion()) {
      els.forEach(function (el) {
        el.classList.add("is-in");
      });
      return;
    }
    var io = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (!entry.isIntersecting) return;
          entry.target.classList.add("is-in");
          io.unobserve(entry.target);
        });
      },
      { rootMargin: "0px 0px -8% 0px", threshold: 0.05 }
    );
    els.forEach(function (el) {
      io.observe(el);
    });
  }

  /* ------------------------------------------------------------------ */
  /* events                                                              */
  /* ------------------------------------------------------------------ */

  function onDocumentClick(event) {
    var sound = event.target.closest("[data-sound-toggle]");
    if (sound) {
      if (sound.closest(".rz-board")) return; // the board owns its own toggle
      if (window.RazeahSound) window.RazeahSound.toggle();
      return;
    }

    var pick = event.target.closest("[data-pick]");
    if (pick) {
      togglePick(pick.getAttribute("data-pick"));
      return;
    }

    var unpick = event.target.closest("[data-unpick]");
    if (unpick) {
      togglePick(unpick.getAttribute("data-unpick"));
      return;
    }

    var noteToggle = event.target.closest("[data-note-toggle]");
    if (noteToggle) {
      toggleNotes(noteToggle.getAttribute("data-note-toggle"));
      return;
    }

    var noteClose = event.target.closest("[data-note-close]");
    if (noteClose) {
      closeNotes(noteClose.getAttribute("data-note-close"));
      return;
    }

    var theater = event.target.closest("[data-theater]");
    if (theater) {
      var stage = document.getElementById("stage-" + theater.getAttribute("data-theater"));
      openTheater(stage);
      return;
    }

    var theaterClose = event.target.closest("[data-theater-close]");
    if (theaterClose) {
      closeTheater();
      return;
    }

    if (event.target.closest("#copySummary") || event.target.closest("#copyTop")) {
      copySummary();
      return;
    }

    if (event.target.closest("#watchAutoplay") || event.target.closest("#watchAutoplay2")) {
      watchAutoplay();
      return;
    }

    if (event.target.closest("#resetPicks")) {
      picks = [];
      save("razeah-review-picks", picks);
      syncPicks();
      showToast("Shortlist cleared");
      return;
    }

    if (event.target.closest("#motionToggle")) {
      setMotion(motion === "reduced" ? "full" : "reduced", true);
    }
  }

  function onDocumentInput(event) {
    var area = event.target.closest("[data-note]");
    if (!area) return;
    setNote(area.getAttribute("data-note"), area.value);
  }

  function onKeydown(event) {
    if (event.key === "Escape" && openStage) {
      closeTheater();
    }
  }

  /* ------------------------------------------------------------------ */
  /* boot                                                                */
  /* ------------------------------------------------------------------ */

  function scrollToHashOnLoad() {
    if (!window.location.hash) return;
    var target = document.getElementById(window.location.hash.slice(1));
    if (!target) return;
    var top = target.getBoundingClientRect().top + window.scrollY - 118;
    window.scrollTo({ top: Math.max(0, top), behavior: "auto" });
  }

  function init() {
    setMotion(motion, false);
    buildHeroFan();
    buildIndex();
    buildDirections();
    buildStatic();
    syncPicks();
    if (window.RazeahSound) window.RazeahSound.sync();

    document.addEventListener("click", onDocumentClick);
    document.addEventListener("input", onDocumentInput);
    document.addEventListener("keydown", onKeydown);
    window.addEventListener("scroll", queueScrollState, { passive: true });
    window.addEventListener("resize", queueScrollState);

    buildReveal();
    updateScrollState();
    setTimeout(scrollToHashOnLoad, 80);
    setTimeout(scrollToHashOnLoad, 650);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();

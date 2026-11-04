/* Neon Reliquary — folio ceremony runtime.
 *
 * State machine:
 *   sealed → cracking → dealing → ready → flipping → summary
 *                                  ↑          ↓
 *                                  └── auto ──┘
 *
 * The contents are committed before CRACK. Nothing in this file decides a
 * card; it only reveals what pack-data already fixed.
 */
(function () {
  "use strict";

  var PD = window.RAZEAH_PACKS;
  var D = window.RAZEAH;
  var I = window.RazeahIcons;

  var mount = document.getElementById("packMount");
  if (!mount || !PD || !D) return;

  var root = null;
  var els = {};
  var timers = new Set();
  var flareTimers = new Map();
  var tellPlayed = new Set();
  var autoTimer = null;
  var summaryTimer = null;
  var stageEl = null;
  var pageToastTimer = null;

  var MOTION_KEY = "razeah-pack-motion";
  var NOTES_KEY = "razeah-pack-notes";
  var RATINGS_KEY = "razeah-pack-ratings";
  var motion = load("razeah-pack-motion", null);
  if (motion !== "reduced" && motion !== "full") {
    motion = window.matchMedia("(prefers-reduced-motion: reduce)").matches ? "reduced" : "full";
  }

  var state = {
    folioIndex: 0,
    opened: [],
    stage: "sealed",
    mode: "ritual",
    auto: false,
    busy: false,
    queued: null,
    hover: null,
    zoom: -1,
    tells: "hover",
    set: 9,
    marks: 2140,
    cards: [],
    revealed: [],
    recent: [],
    ratings: load("razeah-pack-ratings", {}),
    notes: load("razeah-pack-notes", "")
  };
  if (!state.ratings || typeof state.ratings !== "object" || Array.isArray(state.ratings)) {
    state.ratings = {};
  }
  if (typeof state.notes !== "string") state.notes = "";

  /* ------------------------------------------------------------------ */
  /* helpers                                                             */
  /* ------------------------------------------------------------------ */

  function load(key, fallback) {
    try {
      var raw = localStorage.getItem(key);
      return raw ? JSON.parse(raw) : fallback;
    } catch (err) {
      return fallback;
    }
  }

  function save(key, value) {
    try {
      localStorage.setItem(key, JSON.stringify(value));
    } catch (err) {
      /* file:// private mode can reject storage; the lab still works. */
    }
  }

  function esc(value) {
    return String(value).replace(/[&<>"']/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c];
    });
  }

  function fmt(n) {
    return Number(n).toLocaleString("en-US");
  }

  function reduced() {
    return (
      document.body.classList.contains("rz-reduce") ||
      window.matchMedia("(prefers-reduced-motion: reduce)").matches
    );
  }

  function sfx(name) {
    if (window.RazeahSound) window.RazeahSound.play(name, "neon");
  }

  function later(fn, ms) {
    var id = setTimeout(function () {
      timers.delete(id);
      fn();
    }, ms);
    timers.add(id);
    return id;
  }

  function clearTimers() {
    timers.forEach(function (id) {
      clearTimeout(id);
    });
    timers.clear();
    if (autoTimer) {
      clearTimeout(autoTimer);
      autoTimer = null;
    }
    if (summaryTimer) {
      clearTimeout(summaryTimer);
      summaryTimer = null;
    }
  }

  function folio() {
    return PD.folios[state.folioIndex];
  }

  function unopened() {
    return PD.folios.filter(function (f) {
      return state.opened.indexOf(f.id) < 0;
    });
  }

  function rectOf(el) {
    var base = root.getBoundingClientRect();
    var r = el.getBoundingClientRect();
    return {
      x: r.left - base.left,
      y: r.top - base.top,
      w: r.width,
      h: r.height,
      cx: r.left - base.left + r.width / 2,
      cy: r.top - base.top + r.height / 2
    };
  }

  function pipsMarkup(rarity) {
    var info = PD.rarity[rarity];
    var out = '<span class="pk-pips pips-' + info.pips + '">';
    for (var i = 0; i < info.pips; i++) out += "<i></i>";
    out += "</span>";
    return out;
  }

  function tellLabel(rarity) {
    var info = PD.rarity[rarity];
    return info.label + " · " + info.pips + (info.pips === 1 ? " PIP" : " PIPS");
  }

  function inkName(id) {
    return (
      {
        "ink.frost": "INK · FROST",
        "ink.ember": "INK · EMBER",
        "ink.dusk": "INK · DUSK",
        "ink.iron": "INK · IRON"
      }[id] || "INK"
    );
  }

  function inkColor(id) {
    return (
      {
        "ink.frost": "#46f0ff",
        "ink.ember": "#ff3fa4",
        "ink.dusk": "#b06bff",
        "ink.iron": "#d6d0c4"
      }[id] || "#46f0ff"
    );
  }

  function shimmerName(id) {
    return (
      {
        "shimmer.gilt": "SHIMMER · GILT",
        "shimmer.iridescent": "SHIMMER · IRIDESCENT",
        "shimmer.verdigris": "SHIMMER · VERDIGRIS",
        "shimmer.moon": "SHIMMER · MOON"
      }[id] || "SHIMMER"
    );
  }

  function prepareCards(f) {
    var seen = {};
    return f.cards.map(function (entry) {
      var def = D.cards[entry.key];
      var ownedBefore = Number(entry.ownedBefore || 0);
      var seenBefore = Number(seen[entry.key] || 0);
      seen[entry.key] = seenBefore + 1;
      var isNew = ownedBefore === 0 && seenBefore === 0;
      var total = ownedBefore + seenBefore + 1;
      return {
        key: entry.key,
        def: def,
        rarity: def.rarity,
        isNew: isNew,
        total: total,
        stamp: isNew ? "NEW" : "×" + total,
        ink: entry.ink || null,
        shimmer: entry.shimmer || null
      };
    });
  }

  function layoutFor(n) {
    if (n === 3) {
      return {
        w: 16,
        step: 15.2,
        rots: [-2.6, 0, 2.6],
        y: [11.2, 11.6, 11.2]
      };
    }
    return {
      w: 12.4,
      step: 10.9,
      rots: [-5, -2.5, 0, 2.5, 5],
      y: [11.0, 11.35, 11.55, 11.35, 11.0]
    };
  }

  function moteMarkup(rarity, seed) {
    var counts = { common: 8, uncommon: 12, rare: 18, legendary: 24 };
    var count = counts[rarity] || 8;
    var out = "";
    for (var i = 0; i < count; i++) {
      var angle = Math.random() * Math.PI * 2;
      var dist = 5 + Math.random() * 13;
      var size = 0.15 + Math.random() * 0.28;
      out +=
        '<span class="pk-mote" style="--s:' +
        size.toFixed(2) +
        "cqw;--dx:" +
        (Math.cos(angle) * dist).toFixed(2) +
        "cqw;--dy:" +
        (Math.sin(angle) * dist).toFixed(2) +
        "cqw;--rot:" +
        Math.round(Math.random() * 300 - 150) +
        "deg;--delay:" +
        Math.round(Math.random() * 140) +
        "ms;--dur:" +
        Math.round(480 + Math.random() * 460) +
        'ms"></span>';
    }
    return out;
  }

  /* ------------------------------------------------------------------ */
  /* stage markup                                                        */
  /* ------------------------------------------------------------------ */

  function navMarkup() {
    return (
      '<header class="rz-nav">' +
      '<div class="rz-brand"><span class="rz-brand__mark">R</span><span class="rz-brand__word">RAZEAH<small>THE ARTLESS CARD GAME</small></span></div>' +
      '<nav class="rz-tabs" aria-label="Main navigation">' +
      '<button class="rz-tab" type="button" data-pk-stub="Play">Play</button>' +
      '<button class="rz-tab" type="button" data-pk-stub="Library">Library</button>' +
      '<button class="rz-tab" type="button" data-pk-stub="Decks">Decks</button>' +
      '<button class="rz-tab is-active" type="button" data-pk-stub="Packs">Packs<i class="rz-tab__badge" id="pkTabsBadge">3</i></button>' +
      "</nav>" +
      '<div class="rz-navtools">' +
      '<button class="rz-iconbtn" type="button" data-sound-toggle aria-label="Toggle sound">' +
      I.svg("soundOff") +
      "</button>" +
      '<button class="rz-iconbtn" type="button" data-pk-stub="Settings" aria-label="Settings">' +
      I.svg("gear") +
      "</button>" +
      "</div></header>"
    );
  }

  function envelopeMarkup() {
    return (
      '<div class="pk-envelope" id="pkEnvelope">' +
      '<div class="pk-env-body">' +
      '<div class="pk-env-scan"></div>' +
      '<div class="pk-env-flap"></div>' +
      '<div class="pk-env-mouth" id="pkMouth"></div>' +
      '<span class="pk-env-watermark" id="pkEnvWatermark">BRASS</span>' +
      '<div class="pk-env-id"><span id="pkEnvNo">FOLIO 01</span><span id="pkEnvMeta">5 CARDS · PROV 25</span></div>' +
      '<span class="pk-env-corner pk-env-corner--tl"></span><span class="pk-env-corner pk-env-corner--br"></span>' +
      '<div class="pk-flecks" id="pkFlecks"></div>' +
      '<button class="pk-seal" id="pkSeal" type="button" aria-label="Crack the sealed folio">' +
      '<span class="pk-seal__ring"></span>' +
      '<span class="pk-seal__disc"></span>' +
      '<span class="pk-seal__half pk-seal__half--l"></span>' +
      '<span class="pk-seal__half pk-seal__half--r"></span>' +
      '<span class="pk-seal__glyph">' +
      I.svg("spark") +
      "</span>" +
      '<span class="pk-seal__label">CRACK</span>' +
      "</button>" +
      '<svg class="pk-crackline" viewBox="0 0 100 100" aria-hidden="true"><path d="M52 2 L46 18 L55 27 L42 40 L51 52 L40 65 L49 78 L43 98" fill="none" stroke="#ffd6f0" stroke-width="1.5" stroke-linejoin="round" stroke-linecap="round"/></svg>' +
      "</div></div>"
    );
  }

  function roomMarkup() {
    return (
      '<main class="pk-room" id="pkRoom">' +
      '<div class="pk-halo"></div><div class="pk-floor"></div>' +
      envelopeMarkup() +
      '<div class="pk-env-plaque" id="pkPlaque">' +
      '<p class="pk-kicker" id="pkPlaqueKicker">SEALED LOT · 01</p>' +
      '<h2 id="pkPlaqueName">Brass Folio</h2>' +
      '<p id="pkPlaqueMeta">5 cards · rare guaranteed · provenance 25</p>' +
      '<span class="pk-committed">CONTENTS COMMITTED AT ACQUISITION</span>' +
      "</div>" +
      '<div class="pk-fan" id="pkFan"></div>' +
      '<div class="pk-banner" id="pkBanner" role="status" aria-live="polite"></div>' +
      '<div class="pk-bottombar" id="pkBottom">' +
      '<div class="pk-status" id="pkStatus" role="status" aria-live="polite"></div>' +
      '<div class="pk-controls" id="pkControls"></div>' +
      "</div>" +
      '<div class="pk-ledger" id="pkLedger"></div>' +
      '<div class="pk-zoom" id="pkZoom"></div>' +
      '<div class="pk-toast" id="pkToast" role="status" aria-live="polite"></div>' +
      '<div class="pk-fx" id="pkFx"></div>' +
      "</main>"
    );
  }

  function buildStage() {
    var motes = "";
    for (var i = 0; i < 18; i++) {
      motes +=
        '<span style="--x:' +
        (4 + Math.random() * 92).toFixed(1) +
        "%;--d:" +
        (8 + Math.random() * 10).toFixed(1) +
        "s;--delay:" +
        (-Math.random() * 18).toFixed(1) +
        "s;--s:" +
        (0.12 + Math.random() * 0.28).toFixed(2) +
        'cqw"></span>';
    }

    root = document.createElement("div");
    root.className = "pk-stage";
    root.dataset.theme = "neon";
    root.innerHTML =
      '<div class="pk-atmos" aria-hidden="true">' +
      motes +
      "</div>" +
      navMarkup() +
      '<div class="pk-head">' +
      '<div class="pk-head__left"><span class="pk-roomtitle">Satchel Room</span><span class="pk-roomnum" id="pkRoomNum">FOLIO 01 / BRASS</span></div>' +
      '<div class="pk-head__stats"><span>MARKS <b id="pkMarks">2,140</b></span><span>FOLIOS <b id="pkFolios">3</b></span><span>SET <b id="pkSetHead">9 / 16</b></span></div>' +
      "</div>" +
      '<div class="pk-body">' +
      '<aside class="pk-rail pk-rail--left">' +
      '<section class="pk-panel pk-satchel"><div class="pk-panel__label"><span>SATCHEL</span><b id="pkSatchelCount">3 UNOPENED</b></div><div class="pk-satchel-list" id="pkSatchelList"></div></section>' +
      '<section class="pk-panel pk-recent"><div class="pk-panel__label"><span>RECENT PULLS</span><b>LAST 4</b></div><div class="pk-recent-list" id="pkRecentList"></div></section>' +
      "</aside>" +
      roomMarkup() +
      '<aside class="pk-rail pk-rail--right">' +
      '<section class="pk-panel pk-foliodetail" id="pkDetail"></section>' +
      '<section class="pk-panel pk-modepanel"><div class="pk-panel__label"><span>CEREMONY</span><b>MODE</b></div><div class="pk-modes" id="pkModes">' +
      '<button class="pk-modebtn is-active" type="button" data-pk-mode="ritual">RITUAL</button>' +
      '<button class="pk-modebtn" type="button" data-pk-mode="quick">QUICK</button>' +
      '<button class="pk-modebtn" type="button" data-pk-mode="auto">AUTO</button>' +
      '</div><div class="pk-tellmode" id="pkTellMode">' +
      '<button class="is-active" type="button" data-pk-tells="hover">TELLS · HOVER</button>' +
      '<button type="button" data-pk-tells="always">ALWAYS</button>' +
      "</div></section>" +
      '<section class="pk-panel pk-setpanel"><div class="pk-panel__label"><span>SET PROGRESS</span><b>THE ARTLESS SET</b></div><div class="pk-setline"><span id="pkSetLabel">9 / 16 definitions</span><b id="pkSetCount">56%</b></div><div class="pk-setbar"><i id="pkSetBar" style="width:56%"></i></div></section>' +
      '<div class="pk-keeper" id="pkKeeper">“The wax remembers.”</div>' +
      "</aside>" +
      "</div>" +
      '<div class="pk-stage-frame-glow" aria-hidden="true"></div>' +
      '<div class="pk-scan" aria-hidden="true"></div>';

    mount.appendChild(root);

    els.envelope = root.querySelector("#pkEnvelope");
    els.seal = root.querySelector("#pkSeal");
    els.mouth = root.querySelector("#pkMouth");
    els.flecks = root.querySelector("#pkFlecks");
    els.plaque = root.querySelector("#pkPlaque");
    els.plaqueKicker = root.querySelector("#pkPlaqueKicker");
    els.plaqueName = root.querySelector("#pkPlaqueName");
    els.plaqueMeta = root.querySelector("#pkPlaqueMeta");
    els.envNo = root.querySelector("#pkEnvNo");
    els.envMeta = root.querySelector("#pkEnvMeta");
    els.envWatermark = root.querySelector("#pkEnvWatermark");
    els.fan = root.querySelector("#pkFan");
    els.banner = root.querySelector("#pkBanner");
    els.bottom = root.querySelector("#pkBottom");
    els.status = root.querySelector("#pkStatus");
    els.controls = root.querySelector("#pkControls");
    els.ledger = root.querySelector("#pkLedger");
    els.zoom = root.querySelector("#pkZoom");
    els.toast = root.querySelector("#pkToast");
    els.fx = root.querySelector("#pkFx");
    els.detail = root.querySelector("#pkDetail");
    els.modes = root.querySelector("#pkModes");
    els.tellMode = root.querySelector("#pkTellMode");
    els.satchel = root.querySelector("#pkSatchelList");
    els.satchelCount = root.querySelector("#pkSatchelCount");
    els.recent = root.querySelector("#pkRecentList");
    els.marks = root.querySelector("#pkMarks");
    els.folios = root.querySelector("#pkFolios");
    els.setHead = root.querySelector("#pkSetHead");
    els.setLabel = root.querySelector("#pkSetLabel");
    els.setCount = root.querySelector("#pkSetCount");
    els.setBar = root.querySelector("#pkSetBar");
    els.setBarRail = els.setBar;
    els.keeper = root.querySelector("#pkKeeper");
    els.roomNum = root.querySelector("#pkRoomNum");
    els.tabsBadge = root.querySelector("#pkTabsBadge");

    root.addEventListener("click", onStageClick);
    root.addEventListener("mouseover", onStageHover);
    root.addEventListener("mouseout", onStageOut);
    root.addEventListener("focusin", onStageFocus);
    root.addEventListener("focusout", onStageBlur);

    if (window.RazeahSound) window.RazeahSound.sync();
  }

  /* ------------------------------------------------------------------ */
  /* render                                                              */
  /* ------------------------------------------------------------------ */

  function updateHead() {
    var left = unopened().length;
    els.marks.textContent = fmt(state.marks);
    els.folios.textContent = String(left);
    els.setHead.textContent = state.set + " / 16";
    els.satchelCount.textContent = left + (left === 1 ? " UNOPENED" : " UNOPENED");
    if (els.tabsBadge) els.tabsBadge.textContent = String(left);
  }

  function updateSet(animate) {
    var pct = Math.round((state.set / 16) * 100);
    els.setLabel.textContent = state.set + " / 16 definitions";
    els.setCount.textContent = pct + "%";
    if (animate && !reduced()) {
      els.setBar.style.width = ((state.set / 16) * 100).toFixed(2) + "%";
    } else {
      els.setBar.style.width = ((state.set / 16) * 100).toFixed(2) + "%";
    }
  }

  function renderDetail() {
    var f = folio();
    els.detail.innerHTML =
      '<div class="pk-panel__label"><span>THE FOLIO</span><b>COMMITTED</b></div>' +
      '<p class="pk-detail-kicker">SEALED LOT · ' +
      f.no +
      "</p>" +
      '<h3 class="pk-detail-name">' +
      esc(f.name) +
      "</h3>" +
      '<p class="pk-detail-tagline">' +
      esc(f.tagline) +
      "</p>" +
      '<dl class="pk-detail-rows">' +
      "<dt>Cards</dt><dd>" +
      f.cardsCount +
      "</dd>" +
      "<dt>Guarantee</dt><dd class=\"is-hot\">" +
      esc(f.guarantee) +
      "</dd>" +
      "<dt>Provenance</dt><dd>" +
      f.provenance +
      "</dd>" +
      "<dt>Shimmer</dt><dd>" +
      esc(f.shimmerChance) +
      "</dd>" +
      "<dt>Price</dt><dd>" +
      (f.price ? fmt(f.price) + " marks" : "Salvage") +
      "</dd>" +
      "</dl>" +
      '<p class="pk-detail-committed">Contents stored at acquisition. Opening cannot change the roll.</p>';
    els.roomNum.textContent = "FOLIO " + f.no + " / " + f.short.toUpperCase();
    els.envNo.textContent = "FOLIO " + f.no;
    els.envMeta.textContent = f.cardsCount + " CARDS · PROV " + f.provenance;
    if (els.envWatermark) els.envWatermark.textContent = f.short.toUpperCase();
    els.plaqueKicker.textContent = "SEALED LOT · " + f.no;
    els.plaqueName.textContent = f.name;
    els.plaqueMeta.textContent =
      f.cardsCount + " cards · " + f.guarantee.toLowerCase() + " · provenance " + f.provenance;
  }

  function renderSatchel() {
    var f = folio();
    els.satchel.innerHTML = PD.folios
      .map(function (entry, index) {
        var opened = state.opened.indexOf(entry.id) > -1;
        var selected = index === state.folioIndex;
        var locked = !opened && index > state.folioIndex;
        var cls = "pk-folio-row";
        if (selected) cls += " is-selected";
        if (opened) cls += " is-opened";
        if (locked) cls += " is-locked";
        return (
          '<div class="' +
          cls +
          '" data-pk-folio="' +
          index +
          '" role="button" tabindex="' +
          (opened || locked ? "-1" : "0") +
          '">' +
          '<span class="pk-folio-icon" aria-hidden="true"></span>' +
          '<span class="pk-folio-copy"><b>' +
          esc(entry.name) +
          "</b><span>" +
          entry.cardsCount +
          " cards · " +
          esc(entry.guarantee.toLowerCase()) +
          "</span></span>" +
          '<span class="pk-folio-count">' +
          (opened ? "0" : "×1") +
          "</span></div>"
        );
      })
      .join("");
  }

  function renderRecent() {
    if (!state.recent.length) {
      els.recent.innerHTML =
        '<div class="pk-recent-empty">Nothing yet. The ledger is waiting.</div>';
      return;
    }
    els.recent.innerHTML = state.recent
      .slice(-4)
      .map(function (item) {
        var info = PD.rarity[item.rarity];
        return (
          '<div class="pk-recent-row' +
          (item.isNew ? " is-new" : "") +
          '" style="--rarity:' +
          info.color +
          '">' +
          '<span class="pk-recent-pip"></span>' +
          "<b>" +
          esc(item.name) +
          "</b><span>" +
          esc(item.stamp) +
          "</span></div>"
        );
      })
      .join("");
  }

  function renderModes() {
    Array.prototype.forEach.call(els.modes.querySelectorAll("[data-pk-mode]"), function (btn) {
      btn.classList.toggle("is-active", btn.getAttribute("data-pk-mode") === state.mode);
      btn.disabled = state.stage !== "sealed";
    });
    Array.prototype.forEach.call(els.tellMode.querySelectorAll("[data-pk-tells]"), function (btn) {
      btn.classList.toggle("is-active", btn.getAttribute("data-pk-tells") === state.tells);
    });
  }

  function renderStatus() {
    var f = folio();
    var total = state.cards.length || f.cardsCount;
    var done = state.revealed.filter(Boolean).length;
    var pips = "";
    for (var i = 0; i < total; i++) {
      pips += '<i class="' + (state.revealed[i] ? "is-on" : "") + '"></i>';
    }

    var text = "SEALED · " + total + " CARDS · COMMITTED";
    var strong = "";
    if (state.stage === "cracking") {
      text = "01 PRESS · 02 CRACK · THE WAX IS THE VERB";
    } else if (state.stage === "dealing") {
      text = "05 DEAL · THE CARDS ARE ALREADY YOURS";
    } else if (state.stage === "flipping") {
      var turning = state.cards[state.busyIndex];
      if (turning) {
        var ti = PD.rarity[turning.rarity];
        text = ti.label + " · TURNING";
      }
    } else if (state.stage === "summary") {
      var newCount = state.cards.filter(function (c) {
        return c.isNew;
      }).length;
      text = "REVEALED " + done + " · " + newCount + " NEW · SET " + state.set + " / 16";
    } else if (state.stage === "ready") {
      if (state.hover !== null && state.cards[state.hover] && !state.revealed[state.hover]) {
        var hi = PD.rarity[state.cards[state.hover].rarity];
        text = hi.label + " · " + hi.pips + (hi.pips === 1 ? " PIP" : " PIPS") + " · CLICK TO REVEAL";
      } else {
        text = total + " cards · " + done + " of " + total + " revealed · pick one";
      }
    }

    els.status.innerHTML =
      '<span class="pk-status__dot"></span><span class="pk-status__text">' +
      text +
      '</span><span class="pk-progress" aria-hidden="true">' +
      pips +
      "</span>" +
      (strong ? strong : "");
    els.status.setAttribute("aria-label", text);
  }

  function renderControls() {
    if (state.stage === "sealed" || state.stage === "summary") {
      els.controls.innerHTML = "";
      return;
    }
    var autoLabel = state.auto ? "AUTO ON" : "AUTO";
    var out = "";
    if (state.stage === "ready" || state.stage === "flipping") {
      out += '<button class="pk-cbtn" type="button" data-pk-action="reveal-all">REVEAL ALL</button>';
      out +=
        '<button class="pk-cbtn' +
        (state.auto ? " is-on" : "") +
        '" type="button" data-pk-action="auto">' +
        autoLabel +
        "</button>";
    }
    out += '<button class="pk-cbtn pk-cbtn--skip" type="button" data-pk-action="skip">SKIP → LEDGER</button>';
    els.controls.innerHTML = out;
  }

  function keeper(line) {
    if (line) els.keeper.textContent = "“" + line + "”";
  }

  function updateAll(animateSet) {
    updateHead();
    updateSet(animateSet);
    renderDetail();
    renderSatchel();
    renderRecent();
    renderModes();
    renderStatus();
    renderControls();
  }

  /* ------------------------------------------------------------------ */
  /* folio lifecycle                                                     */
  /* ------------------------------------------------------------------ */

  function startFolio(index, fresh) {
    clearTimers();
    closeZoom();
    state.folioIndex = index;
    state.stage = "sealed";
    state.busy = false;
    state.queued = null;
    state.hover = null;
    state.auto = state.mode === "auto";
    state.busyIndex = -1;
    var f = folio();
    state.cards = prepareCards(f);
    state.revealed = state.cards.map(function () {
      return false;
    });
    state.set = Math.max(state.set, f.setBefore);

    root.classList.remove("is-open", "is-summary", "is-shock", "is-changing");
    els.plaque.style.opacity = "";
    els.envelope.classList.remove("is-cracking", "is-open");
    els.envelope.style.animation = "";
    els.seal.disabled = false;
    els.seal.classList.remove("is-pressed");
    els.flecks.innerHTML = "";
    els.fan.innerHTML = "";
    els.banner.classList.remove("is-show");
    els.ledger.classList.remove("is-show");
    els.ledger.innerHTML = "";
    els.zoom.classList.remove("is-open");
    els.toast.classList.remove("is-show");
    tellPlayed = new Set();
    flareTimers.forEach(function (t) {
      clearTimeout(t);
    });
    flareTimers.clear();

    updateAll(false);
    keeper(state.stage === "sealed" ? "The wax remembers." : "");
    if (els.status) els.status.style.opacity = "1";
    if (fresh) {
      /* The intro should land on a sealed object, not a toast. */
      els.toast.classList.remove("is-show");
    }
  }

  function crack() {
    if (state.stage !== "sealed" || state.busy) return;
    state.busy = true;
    state.stage = "cracking";
    els.seal.classList.add("is-pressed");
    els.seal.disabled = true;
    sfx("folioPress");
    renderStatus();
    renderControls();

    later(function () {
      els.seal.classList.remove("is-pressed");
      els.envelope.classList.add("is-cracking");
      sfx("folioCrack");
      spawnFlecks(12);
      renderStatus();
    }, reduced() ? 10 : 90);

    later(function () {
      els.envelope.classList.add("is-open");
      root.classList.add("is-open");
      sfx("folioFlap");
      renderStatus();
    }, reduced() ? 30 : 230);

    later(function () {
      if (state.stage !== "cracking") return;
      state.stage = "dealing";
      buildFan();
      dealFan();
      renderStatus();
      renderControls();
    }, reduced() ? 60 : 480);
  }

  function spawnFlecks(count) {
    if (reduced()) return;
    for (var i = 0; i < count; i++) {
      var el = document.createElement("span");
      el.className = "pk-fleck";
      var angle = Math.random() * Math.PI * 2;
      var dist = 24 + Math.random() * 54;
      var size = 2 + Math.random() * 4;
      el.style.setProperty("--s", size + "px");
      els.flecks.appendChild(el);
      el.animate(
        [
          { transform: "translate(-50%,-50%) rotate(45deg) scale(1)", opacity: 1 },
          {
            transform:
              "translate(calc(-50% + " +
              Math.cos(angle) * dist +
              "px), calc(-50% + " +
              (Math.sin(angle) * dist + 28) +
              "px)) rotate(" +
              (Math.random() * 260 - 130) +
              "deg) scale(.5)",
            opacity: 0
          }
        ],
        { duration: 420 + Math.random() * 220, easing: "ease-out" }
      );
      (function (node) {
        setTimeout(function () {
          node.remove();
        }, 760);
      })(el);
    }
  }

  function buildFan() {
    var n = state.cards.length;
    var layout = layoutFor(n);
    var center = (n - 1) / 2;
    els.fan.innerHTML = state.cards
      .map(function (card, i) {
        return slotMarkup(card, i, layout, center, n);
      })
      .join("");
    state.revealed = state.cards.map(function () {
      return false;
    });
    applyTellMode();
  }

  function cardAria(card, revealed) {
    var info = PD.rarity[card.rarity];
    if (!revealed) {
      return (
        "Face-down card. " +
        info.label +
        " tell, " +
        info.pips +
        (info.pips === 1 ? " pip" : " pips") +
        ". Press to reveal."
      );
    }
    return (
      card.def.name +
      ". " +
      info.label +
      ". " +
      card.stamp +
      ". Press to inspect."
    );
  }

  function slotMarkup(card, i, layout, center, n) {
    var info = PD.rarity[card.rarity];
    var x = ((i - center) * layout.step).toFixed(2);
    var y = layout.y[i].toFixed(2);
    var rot = layout.rots[i];
    var holo =
      card.shimmer === "shimmer.iridescent"
        ? " pk-holo--iridescent"
        : card.shimmer === "shimmer.gilt"
          ? " pk-holo--gilt"
          : "";
    var ink = card.ink
      ? '<div class="pk-inkrim" style="--ink-color:' + inkColor(card.ink) + '"></div>'
      : "";
    var mod = card.shimmer ? shimmerName(card.shimmer) : card.ink ? inkName(card.ink) : "";
    var stampClass = card.isNew ? "is-new" : "is-dupe";

    return (
      '<div class="pk-card-slot" data-index="' +
      i +
      '" data-rarity="' +
      card.rarity +
      '" style="--x:' +
      x +
      "cqw;--y:" +
      y +
      "cqw;--rot:" +
      rot +
      "deg;--z:" +
      (10 + i) +
      ";--pk-card-w:" +
      layout.w +
      'cqw" role="button" tabindex="0" aria-label="' +
      cardAria(card, false) +
      '">' +
      '<div class="pk-card-move">' +
      '<div class="pk-card-tilt">' +
      '<div class="pk-aura" aria-hidden="true">' +
      '<span class="pk-flare-ring r1"></span><span class="pk-flare-ring r2"></span>' +
      '<span class="pk-flare-ticks"></span><span class="pk-flare-rays"></span>' +
      '<div class="pk-motes">' +
      moteMarkup(card.rarity) +
      "</div></div>" +
      '<div class="pk-flipper">' +
      '<div class="pk-face pk-face--back">' +
      window.RazeahBoard.backMarkup(false) +
      '<div class="pk-back-tell">' +
      pipsMarkup(card.rarity) +
      '<span class="pk-tell-label">' +
      tellLabel(card.rarity) +
      "</span></div>" +
      "</div>" +
      '<div class="pk-face pk-face--front">' +
      window.RazeahBoard.cardMarkup(card.key) +
      '<div class="pk-holo' +
      holo +
      '"></div>' +
      ink +
      "</div>" +
      "</div>" +
      '<span class="pk-paper-edge"></span>' +
      '<span class="pk-stamp ' +
      stampClass +
      '">' +
      esc(card.stamp) +
      "</span>" +
      (mod ? '<span class="pk-modchip">' + mod + "</span>" : "") +
      "</div></div></div>"
    );
  }

  function dealFan() {
    var slots = els.fan.querySelectorAll(".pk-card-slot");
    var mouth = rectOf(els.mouth);
    var n = slots.length;
    Array.prototype.forEach.call(slots, function (slot, i) {
      var move = slot.querySelector(".pk-card-move");
      var r = rectOf(slot);
      var dx = mouth.cx - r.cx;
      var dy = mouth.cy - r.cy;
      move.style.transform = "translate(" + dx + "px," + dy + "px) scale(.78)";
      move.style.opacity = "0";
      var anim = move.animate(
        [
          {
            transform: "translate(" + dx + "px," + dy + "px) scale(.78)",
            opacity: 0
          },
          {
            transform:
              "translate(" +
              dx * 0.48 +
              "px," +
              (dy * 0.35 - 14) +
              "px) scale(.92)",
            opacity: 1,
            offset: 0.46
          },
          { transform: "translate(0,0) scale(1.045)", opacity: 1, offset: 0.88 },
          { transform: "translate(0,0) scale(1)", opacity: 1 }
        ],
        {
          duration: reduced() ? 1 : 480,
          delay: reduced() ? 0 : i * 55,
          easing: "linear",
          fill: "both"
        }
      );
      later(function () {
        sfx("folioDeal");
      }, i * 55);
    });

    later(function () {
      if (state.stage !== "dealing") return;
      state.stage = "ready";
      state.busy = false;
      renderStatus();
      renderControls();
      applyTellMode();
      var first = els.fan.querySelector(".pk-card-slot");
      if (first) {
        try {
          first.focus({ preventScroll: true });
        } catch (err) {
          /* older focus signature; no-op */
        }
      }
      if (state.auto || state.mode === "auto") {
        state.auto = true;
        scheduleAuto(480);
      }
    }, reduced() ? 30 : 480 + 55 * (n - 1) + 270);
  }

  /* ------------------------------------------------------------------ */
  /* tell + flip                                                         */
  /* ------------------------------------------------------------------ */

  function applyTellMode() {
    Array.prototype.forEach.call(els.fan.querySelectorAll(".pk-card-slot"), function (slot) {
      var i = Number(slot.getAttribute("data-index"));
      var shouldShow =
        state.tells === "always" && !state.revealed[i] && state.stage !== "sealed";
      if (state.hover === i && !state.revealed[i]) shouldShow = true;
      slot.classList.toggle("is-telling", shouldShow);
    });
  }

  function hoverCard(index) {
    if (state.revealed[index]) return;
    if (state.stage !== "ready" && state.stage !== "flipping") return;
    state.hover = index;
    applyTellMode();
    renderStatus();
    var card = state.cards[index];
    if (!tellPlayed.has(index)) {
      tellPlayed.add(index);
      var cue =
        card.rarity === "legendary"
          ? "folioTellLegendary"
          : card.rarity === "rare"
            ? "folioTellRare"
            : card.rarity === "uncommon"
              ? "folioTellUncommon"
              : "folioTellCommon";
      sfx(cue);
    }
  }

  function unhoverCard(index) {
    if (state.hover !== index) return;
    state.hover = null;
    applyTellMode();
    renderStatus();
  }

  function flip(index, fromAuto) {
    if (state.stage !== "ready" && state.stage !== "flipping") return;
    if (state.revealed[index]) {
      openZoom(index);
      return;
    }
    if (state.busy) {
      state.queued = index;
      return;
    }
    if (!fromAuto && state.auto) {
      stopAuto();
    }
    state.busy = true;
    state.busyIndex = index;
    state.stage = "flipping";
    state.queued = null;
    state.hover = null;
    var slot = els.fan.querySelector('.pk-card-slot[data-index="' + index + '"]');
    if (!slot) {
      state.busy = false;
      state.stage = "ready";
      return;
    }
    var card = state.cards[index];
    var flipper = slot.querySelector(".pk-flipper");
    var edge = slot.querySelector(".pk-paper-edge");
    slot.classList.remove("is-telling");
    sfx("folioFlip");
    renderStatus();
    renderControls();

    var quick = state.mode === "quick";
    var total = reduced() ? 1 : (quick ? 190 : 470);
    var flareAt = reduced() ? 0 : Math.round(total * 0.68);
    var stampAt = reduced() ? 0 : Math.round(total * 0.7);
    var midAt = reduced() ? 0 : Math.round(total * 0.48);

    if (!reduced()) {
      flipper.animate(
        [
          { transform: "translateY(0) scale(1) rotateY(0deg)", easing: "ease-out" },
          {
            transform: "translateY(-6px) scale(1.035) rotateY(0deg)",
            offset: 0.17,
            easing: "ease-in"
          },
          {
            transform: "translateY(0) scaleX(.88) scaleY(1.03) rotateY(0deg)",
            offset: 0.32,
            easing: "ease-in-out"
          },
          {
            transform: "translateY(0) scale(1.045) rotateY(180deg)",
            offset: 0.55,
            easing: "linear"
          },
          {
            transform: "translateY(0) scale(1.045) rotateY(180deg)",
            offset: 0.68,
            easing: "ease-out"
          },
          { transform: "translateY(0) scale(1) rotateY(180deg)", offset: 1 }
        ],
        { duration: total, easing: "linear", fill: "forwards" }
      );
      later(function () {
        if (!slot.isConnected) return;
        slot.classList.add("is-turning");
        later(function () {
          slot.classList.remove("is-turning");
        }, 140);
      }, midAt);
    }

    later(function () {
      if (!slot.isConnected) return;
      pulseStamp(slot);
      showFlare(index);
      sfx(card.rarity === "legendary" ? "folioLegendary" : card.rarity === "rare" ? "folioRare" : null);
      if (card.rarity !== "common" && card.rarity !== "uncommon") {
        showBanner(card);
      }
    }, flareAt);

    later(function () {
      finishFlip(index, slot, flipper);
    }, total + (reduced() ? 0 : 10));
  }

  function finishFlip(index, slot, flipper) {
    var card = state.cards[index];
    slot.classList.add("is-faceup");
    slot.classList.remove("is-flipping");
    slot.classList.add("is-stamped");
    state.revealed[index] = true;
    slot.setAttribute("aria-label", cardAria(card, true));
    state.busy = false;
    state.busyIndex = -1;
    state.stage = "ready";
    var info = PD.rarity[card.rarity];
    state.recent.push({
      name: card.def.name,
      rarity: card.rarity,
      stamp: card.stamp,
      isNew: card.isNew
    });
    keeper(
      card.rarity === "legendary"
        ? "The Unbound answers."
        : card.rarity === "rare"
          ? "A rare cut. Hold it."
          : card.rarity === "uncommon"
            ? "The ledger brightens."
            : "A quiet cut."
    );
    renderRecent();
    renderStatus();
    renderControls();
    applyTellMode();
    if (window.RazeahSound) window.RazeahSound.play("folioStamp", "neon");

    var all = state.revealed.every(Boolean);
    if (all) {
      scheduleSummary(card.rarity, 250);
    } else if (state.auto) {
      scheduleAuto(state.mode === "quick" ? 240 : 650);
    } else if (state.queued !== null) {
      var q = state.queued;
      state.queued = null;
      later(function () {
        flip(q, false);
      }, 80);
    }
  }

  function pulseStamp(slot) {
    slot.classList.add("is-stamped");
    slot.querySelector(".pk-stamp");
  }

  function showFlare(index) {
    var slot = els.fan.querySelector('.pk-card-slot[data-index="' + index + '"]');
    if (!slot) return;
    clearOtherFlares(index);
    slot.classList.add("is-flaring");
    if (state.cards[index].rarity === "legendary") {
      root.classList.add("is-shock");
      later(function () {
        root.classList.remove("is-shock");
      }, 200);
    }
    var duration =
      state.cards[index].rarity === "legendary"
        ? 940
        : state.cards[index].rarity === "rare"
          ? 480
          : state.cards[index].rarity === "uncommon"
            ? 280
            : 180;
    var timer = setTimeout(function () {
      slot.classList.remove("is-flaring");
      flareTimers.delete(index);
    }, duration);
    flareTimers.set(index, timer);
  }

  function clearOtherFlares(except) {
    flareTimers.forEach(function (timer, index) {
      if (index === except) return;
      clearTimeout(timer);
      flareTimers.delete(index);
      var s = els.fan.querySelector('.pk-card-slot[data-index="' + index + '"]');
      if (s) s.classList.remove("is-flaring");
    });
  }

  function showBanner(card) {
    var info = PD.rarity[card.rarity];
    els.banner.setAttribute("data-rarity", card.rarity);
    els.banner.innerHTML =
      '<span class="pk-banner__kicker">' +
      info.label +
      " · " +
      info.pips +
      (info.pips === 1 ? " PIP" : " PIPS") +
      "</span><strong>" +
      esc(card.def.name) +
      "</strong>";
    els.banner.classList.remove("is-show");
    void els.banner.offsetWidth;
    els.banner.classList.add("is-show");
    clearTimeout(els.banner._timer);
    els.banner._timer = setTimeout(function () {
      els.banner.classList.remove("is-show");
    }, card.rarity === "legendary" ? 2700 : 1900);
  }

  function scheduleSummary(lastRarity, delay) {
    if (summaryTimer) clearTimeout(summaryTimer);
    var extra =
      lastRarity === "legendary" ? 900 : lastRarity === "rare" ? 480 : 260;
    summaryTimer = setTimeout(function () {
      summaryTimer = null;
      showSummary();
    }, reduced() ? 20 : Math.max(delay || 0, extra));
  }

  function showSummary() {
    if (state.stage === "summary") return;
    clearTimers();
    state.stage = "summary";
    state.busy = false;
    state.auto = false;
    state.queued = null;
    state.hover = null;
    var f = folio();
    state.opened.push(f.id);
    state.set = f.setAfter;
    root.classList.add("is-summary");
    renderSatchel();
    renderRecent();
    renderModes();
    renderStatus();
    renderControls();
    updateHead();
    updateSet(true);
    keeper(f.keeper);
    renderLedger();
    els.ledger.classList.add("is-show");
    sfx("folioSummary");
    if (state.set >= 16) {
      els.banner.setAttribute("data-rarity", "legendary");
      els.banner.innerHTML =
        '<span class="pk-banner__kicker">SET COMPLETE</span><strong>THE ARTLESS SET</strong>';
      els.banner.classList.remove("is-show");
      void els.banner.offsetWidth;
      els.banner.classList.add("is-show");
      clearTimeout(els.banner._timer);
      els.banner._timer = setTimeout(function () {
        els.banner.classList.remove("is-show");
      }, 2800);
    }
    later(function () {
      var primary = els.ledger.querySelector(".pk-lbtn--primary");
      if (primary) {
        try {
          primary.focus({ preventScroll: true });
        } catch (err) {}
      }
    }, 60);
  }

  function skipToSummary() {
    if (state.stage === "summary" || state.stage === "sealed") return;
    clearTimers();
    state.auto = false;
    if (!state.cards.length) return;
    if (!els.fan.children.length) buildFan();
    root.classList.add("is-open");
    els.envelope.classList.add("is-open");
    els.plaque.style.opacity = "0";
    state.revealed = state.cards.map(function () {
      return true;
    });
    Array.prototype.forEach.call(els.fan.querySelectorAll(".pk-card-slot"), function (slot) {
      var i = Number(slot.getAttribute("data-index"));
      var flipper = slot.querySelector(".pk-flipper");
      if (flipper) {
        flipper.getAnimations().forEach(function (a) {
          a.cancel();
        });
      }
      var move = slot.querySelector(".pk-card-move");
      if (move) {
        move.getAnimations().forEach(function (a) {
          a.cancel();
        });
        move.style.transform = "none";
        move.style.opacity = "1";
      }
      slot.classList.add("is-faceup", "is-stamped");
      slot.classList.remove("is-telling", "is-flaring", "is-turning");
      slot.setAttribute("aria-label", cardAria(state.cards[i], true));
    });
    state.cards.forEach(function (c) {
      if (!state.recent.some(function (r) {
        return r.name === c.def.name && r.stamp === c.stamp;
      })) {
        state.recent.push({
          name: c.def.name,
          rarity: c.rarity,
          stamp: c.stamp,
          isNew: c.isNew
        });
      }
    });
    renderRecent();
    renderStatus();
    renderControls();
    sfx("folioSkip");
    showSummary();
  }

  function revealAll() {
    if (state.stage === "summary" || state.stage === "sealed") return;
    clearTimers();
    state.auto = false;
    state.busy = false;
    if (!els.fan.children.length) buildFan();
    root.classList.add("is-open");
    els.envelope.classList.add("is-open");
    els.plaque.style.opacity = "0";
    state.revealed = state.cards.map(function () {
      return true;
    });
    var slots = Array.prototype.slice.call(els.fan.querySelectorAll(".pk-card-slot"));
    var best = "common";
    state.cards.forEach(function (c) {
      if (c.rarity === "legendary") best = "legendary";
      else if (c.rarity === "rare" && best !== "legendary") best = "rare";
      else if (c.rarity === "uncommon" && best === "common") best = "uncommon";
    });
    slots.forEach(function (slot, i) {
      var flipper = slot.querySelector(".pk-flipper");
      if (flipper) {
        flipper.getAnimations().forEach(function (a) {
          a.cancel();
        });
      }
      slot.classList.add("is-faceup", "is-stamped");
      slot.classList.remove("is-telling", "is-turning");
      slot.setAttribute("aria-label", cardAria(state.cards[i], true));
      state.cards.forEach(function (c) {
        if (!state.recent.some(function (r) {
          return r.name === c.def.name && r.stamp === c.stamp;
        })) {
          state.recent.push({
            name: c.def.name,
            rarity: c.rarity,
            stamp: c.stamp,
            isNew: c.isNew
          });
        }
      });
      if (state.cards[i].rarity === best) {
        showFlare(i);
      }
    });
    renderRecent();
    renderStatus();
    renderControls();
    sfx(best === "legendary" ? "folioLegendary" : best === "rare" ? "folioRare" : "folioSummary");
    later(function () {
      showSummary();
    }, reduced() ? 20 : best === "legendary" ? 720 : 520);
  }

  /* ------------------------------------------------------------------ */
  /* auto / modes                                                        */
  /* ------------------------------------------------------------------ */

  function scheduleAuto(delay) {
    if (autoTimer) clearTimeout(autoTimer);
    if (!state.auto) return;
    autoTimer = setTimeout(function () {
      autoTimer = null;
      if (!state.auto) return;
      var next = state.revealed.indexOf(false);
      if (next < 0) {
        scheduleSummary(state.cards[state.cards.length - 1].rarity, 0);
        return;
      }
      flip(next, true);
    }, delay);
  }

  function stopAuto() {
    state.auto = false;
    if (autoTimer) {
      clearTimeout(autoTimer);
      autoTimer = null;
    }
    renderControls();
  }

  function toggleAuto() {
    if (state.stage !== "ready" && state.stage !== "flipping") return;
    if (state.auto) {
      stopAuto();
      showToast("AUTO OFF · TAKE THE NEXT CARD");
      return;
    }
    state.auto = true;
    renderControls();
    showToast("AUTO ON · " + (state.mode === "quick" ? "QUICK CADENCE" : "RITUAL CADENCE"));
    scheduleAuto(180);
  }

  function setMode(mode) {
    if (state.stage !== "sealed") return;
    state.mode = mode;
    state.auto = mode === "auto";
    renderModes();
    renderControls();
    keeper(mode === "auto" ? "The ledger will turn them for you." : "The wax remembers.");
    showToast(
      mode === "ritual"
        ? "RITUAL · YOU TURN EVERY CARD"
        : mode === "quick"
          ? "QUICK · 190 MS FLIPS"
          : "AUTO · THE LEDGER TURNS THEM"
    );
  }

  function setTells(value) {
    state.tells = value === "always" ? "always" : "hover";
    renderModes();
    applyTellMode();
    renderStatus();
    showToast(value === "always" ? "TELLS · ALWAYS VISIBLE" : "TELLS · HOVER OR FOCUS");
  }

  /* ------------------------------------------------------------------ */
  /* ledger + navigation                                                 */
  /* ------------------------------------------------------------------ */

  function renderLedger() {
    var f = folio();
    var cards = state.cards.length;
    var newCount = state.cards.filter(function (c) {
      return c.isNew;
    }).length;
    var reagents = f.reagents.length;
    var mods = state.cards.filter(function (c) {
      return !!(c.shimmer || c.ink);
    }).length;
    var thirdLabel = reagents ? "REAGENT" : "MODS";
    var thirdValue = reagents ? reagents : mods;
    var thirdClass = reagents ? "pk-lchip--new" : "";
    var nextIndex = PD.folios.findIndex(function (entry, index) {
      return state.opened.indexOf(entry.id) < 0 && index !== state.folioIndex;
    });
    var hasNext = nextIndex > -1;
    var primary = hasNext ? "OPEN ANOTHER" : "RESET DEMO";
    var primaryAction = hasNext ? "open-another" : "reset-demo";
    var secondary = hasNext ? "RESET DEMO" : "DIRECTIONS";
    var secondaryAction = hasNext ? "reset-demo" : "directions";

    els.ledger.innerHTML =
      '<div class="pk-ledger__top">' +
      '<div class="pk-ledger__chips">' +
      '<div class="pk-lchip"><b data-count="' +
      cards +
      '">0</b><span>CARDS</span></div>' +
      '<div class="pk-lchip pk-lchip--new"><b data-count="' +
      newCount +
      '">0</b><span>NEW</span></div>' +
      '<div class="pk-lchip ' +
      thirdClass +
      '"><b data-count="' +
      thirdValue +
      '">0</b><span>' +
      thirdLabel +
      "</span></div>" +
      '<div class="pk-lchip pk-lchip--set"><b data-count="' +
      state.set +
      '">0</b><span>SET / 16</span></div>' +
      "</div>" +
      '<div class="pk-ledger__gauge">' +
      '<div class="pk-ledger__gaugehead"><span>THE ARTLESS SET</span><b id="pkLedgerSet">' +
      state.set +
      " / 16</b></div>" +
      '<div class="pk-ledger__gaugebar"><i id="pkLedgerBar" style="width:' +
      (f.setBefore / 16) * 100 +
      '%"></i></div>' +
      "</div>" +
      '<div class="pk-ledger__actions">' +
      '<button class="pk-lbtn pk-lbtn--primary" type="button" data-pk-action="' +
      primaryAction +
      '">' +
      primary +
      "</button>" +
      '<button class="pk-lbtn" type="button" data-pk-action="' +
      secondaryAction +
      '">' +
      secondary +
      "</button>" +
      "</div></div>" +
      '<div class="pk-ledger__foot"><span><b>THE FAN STAYS.</b> CLICK A CARD TO INSPECT.</span><span><b>COMMITTED BEFORE THE FIRST FRAME.</b></span></div>';

    var countEls = els.ledger.querySelectorAll("[data-count]");
    Array.prototype.forEach.call(countEls, function (el) {
      var target = Number(el.getAttribute("data-count"));
      animateCount(el, target, 240);
    });
    var bar = els.ledger.querySelector("#pkLedgerBar");
    if (bar) {
      requestAnimationFrame(function () {
        bar.style.width = ((state.set / 16) * 100).toFixed(2) + "%";
      });
    }
  }

  function animateCount(el, target, duration) {
    if (reduced()) {
      el.textContent = String(target);
      return;
    }
    var start = performance.now();
    var from = 0;
    function tick(now) {
      var t = Math.min(1, (now - start) / duration);
      var eased = 1 - Math.pow(1 - t, 3);
      el.textContent = String(Math.round(from + (target - from) * eased));
      if (t < 1) requestAnimationFrame(tick);
      else el.textContent = String(target);
    }
    requestAnimationFrame(tick);
  }

  function openAnother() {
    var nextIndex = PD.folios.findIndex(function (entry, index) {
      return state.opened.indexOf(entry.id) < 0 && index !== state.folioIndex;
    });
    if (nextIndex < 0) {
      resetDemo();
      return;
    }
    if (reduced()) {
      startFolio(nextIndex);
      return;
    }
    root.classList.add("is-changing");
    later(function () {
      startFolio(nextIndex);
      root.classList.remove("is-changing");
    }, 220);
  }

  function resetDemo() {
    state.opened = [];
    state.recent = [];
    state.set = PD.folios[0].setBefore;
    state.mode = "ritual";
    state.auto = false;
    state.folioIndex = 0;
    startFolio(0);
    pageToast("DEMO RESET · THREE FOLIOS ON THE DESK");
  }

  /* ------------------------------------------------------------------ */
  /* zoom                                                                */
  /* ------------------------------------------------------------------ */

  function openZoom(index) {
    var card = state.cards[index];
    if (!card) return;
    var info = PD.rarity[card.rarity];
    var holo =
      card.shimmer === "shimmer.iridescent"
        ? " pk-holo--iridescent"
        : card.shimmer === "shimmer.gilt"
          ? " pk-holo--gilt"
          : "";
    var ink = card.ink
      ? '<div class="pk-inkrim" style="--ink-color:' + inkColor(card.ink) + '"></div>'
      : "";
    els.zoom.innerHTML =
      '<div class="pk-zoom__inner" role="dialog" aria-modal="true" aria-label="' +
      esc(card.def.name) +
      '">' +
      '<button class="pk-zoom__close" type="button" data-pk-action="zoom-close" aria-label="Close card">' +
      I.svg("close") +
      "</button>" +
      '<div class="pk-zoom__card">' +
      window.RazeahBoard.cardMarkup(card.key) +
      '<div class="pk-holo' +
      holo +
      '"></div>' +
      ink +
      "</div>" +
      '<div class="pk-zoom__info">' +
      '<p class="pk-zoom__kicker">' +
      info.label +
      " · " +
      info.pips +
      (info.pips === 1 ? " PIP" : " PIPS") +
      "</p>" +
      '<h3 class="pk-zoom__name">' +
      esc(card.def.name) +
      "</h3>" +
      '<div class="pk-zoom__meta"><span class="' +
      (card.rarity === "legendary" ? "pink" : card.rarity === "rare" ? "amber" : "") +
      '">' +
      info.label +
      "</span><span>" +
      card.stamp +
      "</span>" +
      (card.shimmer ? '<span class="amber">' + shimmerName(card.shimmer) + "</span>" : "") +
      (card.ink ? "<span>" + inkName(card.ink) + "</span>" : "") +
      "</div>" +
      '<p class="pk-zoom__rules">' +
      esc(card.def.rules) +
      "</p>" +
      "</div></div>";
    els.zoom.classList.add("is-open");
    state.zoom = index;
    var close = els.zoom.querySelector(".pk-zoom__close");
    if (close) {
      try {
        close.focus({ preventScroll: true });
      } catch (err) {}
    }
  }

  function closeZoom() {
    if (!els.zoom) return;
    els.zoom.classList.remove("is-open");
    els.zoom.innerHTML = "";
    state.zoom = -1;
  }

  /* ------------------------------------------------------------------ */
  /* stage events                                                        */
  /* ------------------------------------------------------------------ */

  function indexOfSlot(slot) {
    return Number(slot.getAttribute("data-index"));
  }

  function onStageClick(event) {
    var stub = event.target.closest("[data-pk-stub]");
    if (stub) {
      showToast(stub.getAttribute("data-pk-stub").toUpperCase() + " · THIS ROOM IS PACKS");
      return;
    }
    if (event.target.closest("#pkSeal")) {
      crack();
      return;
    }
    var mode = event.target.closest("[data-pk-mode]");
    if (mode) {
      setMode(mode.getAttribute("data-pk-mode"));
      return;
    }
    var tell = event.target.closest("[data-pk-tells]");
    if (tell) {
      setTells(tell.getAttribute("data-pk-tells"));
      return;
    }
    var folioRow = event.target.closest("[data-pk-folio]");
    if (folioRow) {
      var idx = Number(folioRow.getAttribute("data-pk-folio"));
      if (idx === state.folioIndex) showToast("THIS FOLIO IS ALREADY ON THE DESK");
      else if (state.opened.indexOf(PD.folios[idx].id) > -1) showToast("FOLIO ALREADY OPENED");
      else showToast("THE TOP FOLIO FIRST · OPEN ANOTHER ADVANCES");
      return;
    }
    var action = event.target.closest("[data-pk-action]");
    if (action) {
      var name = action.getAttribute("data-pk-action");
      if (name === "skip") skipToSummary();
      else if (name === "reveal-all") revealAll();
      else if (name === "auto") toggleAuto();
      else if (name === "open-another") openAnother();
      else if (name === "reset-demo") resetDemo();
      else if (name === "directions") window.location.href = "index.html#neon";
      else if (name === "zoom-close") closeZoom();
      return;
    }
    if (event.target.closest(".pk-zoom") && !event.target.closest(".pk-zoom__inner")) {
      closeZoom();
      return;
    }
    var slot = event.target.closest(".pk-card-slot");
    if (slot) {
      var i = indexOfSlot(slot);
      if (state.revealed[i]) openZoom(i);
      else if (state.stage === "ready" || state.stage === "flipping") flip(i, false);
    }
  }

  function onStageHover(event) {
    var slot = event.target.closest(".pk-card-slot");
    if (!slot) return;
    hoverCard(indexOfSlot(slot));
  }

  function onStageOut(event) {
    var slot = event.target.closest(".pk-card-slot");
    if (!slot) return;
    var related = event.relatedTarget;
    if (related && slot.contains(related)) return;
    unhoverCard(indexOfSlot(slot));
  }

  function onStageFocus(event) {
    var slot = event.target.closest(".pk-card-slot");
    if (slot) hoverCard(indexOfSlot(slot));
  }

  function onStageBlur(event) {
    var slot = event.target.closest(".pk-card-slot");
    if (slot) unhoverCard(indexOfSlot(slot));
  }

  /* ------------------------------------------------------------------ */
  /* page: toast, theater, notes, ratings                                */
  /* ------------------------------------------------------------------ */

  function showToast(text) {
    if (!els.toast) return;
    els.toast.textContent = text;
    els.toast.classList.add("is-show");
    clearTimeout(els.toast._timer);
    els.toast._timer = setTimeout(function () {
      els.toast.classList.remove("is-show");
    }, 2200);
  }

  function pageToast(text) {
    var el = document.getElementById("siteToast");
    if (!el) return;
    el.textContent = text;
    el.classList.add("is-show");
    clearTimeout(pageToastTimer);
    pageToastTimer = setTimeout(function () {
      el.classList.remove("is-show");
    }, 2600);
  }

  function openTheater() {
    var frame = document.getElementById("pkFrame");
    if (!frame) return;
    frame.classList.add("is-theater");
    document.body.classList.add("pk-theater-open");
    var close = document.getElementById("pkTheaterClose");
    if (close) {
      try {
        close.focus({ preventScroll: true });
      } catch (err) {}
    }
  }

  function closeTheater() {
    var frame = document.getElementById("pkFrame");
    if (!frame) return;
    frame.classList.remove("is-theater");
    document.body.classList.remove("pk-theater-open");
    var opener = document.getElementById("pkTheaterOpen");
    if (opener) {
      try {
        opener.focus({ preventScroll: true });
      } catch (err) {}
    }
  }

  function setMotion(value, announce) {
    motion = value === "reduced" ? "reduced" : "full";
    save(MOTION_KEY, motion);
    document.body.classList.toggle("rz-reduce", motion === "reduced");
    var btn = document.getElementById("packMotion");
    if (btn) {
      btn.textContent = motion === "reduced" ? "Motion: reduced" : "Motion: full";
      btn.setAttribute("aria-pressed", motion === "reduced" ? "true" : "false");
    }
    if (announce) {
      pageToast(motion === "reduced" ? "MOTION REDUCED EVERYWHERE" : "FULL MOTION RESTORED");
    }
  }

  function buildTellGrid() {
    var el = document.getElementById("tellGrid");
    if (!el) return;
    el.innerHTML = PD.rarity
      ? ["common", "uncommon", "rare", "legendary"]
          .map(function (rarity) {
            var info = PD.rarity[rarity];
            var back = window.RazeahBoard.backMarkup(false);
            return (
              '<article class="pk-tell-demo" data-rarity="' +
              rarity +
              '" style="--r-color:' +
              info.color +
              '">' +
              '<div class="rz-skin" data-theme="neon"><div class="pk-tell-demo__card">' +
              back +
              '<div class="pk-tell-demo__tell">' +
              pipsMarkup(rarity) +
              '<span class="pk-tell-label">' +
              tellLabel(rarity) +
              "</span></div></div></div>" +
              '<div class="pk-tell-demo__name">' +
              info.label +
              "</div>" +
              '<p class="pk-tell-demo__copy">' +
              info.note +
              "</p></article>"
            );
          })
          .join("")
      : "";
  }

  function buildBeats() {
    var el = document.getElementById("beatGrid");
    if (!el) return;
    el.innerHTML = PD.beats
      .map(function (b) {
        return (
          '<article class="pk-beat"><div class="pk-beat__no"><b>' +
          b.no +
          "</b><span>" +
          b.time +
          "</span></div><h3>" +
          b.title +
          "</h3><p>" +
          b.copy +
          "</p></article>"
        );
      })
      .join("");
  }

  function buildReject() {
    var el = document.getElementById("rejectList");
    if (!el) return;
    el.innerHTML = PD.reject
      .map(function (r) {
        return "<li><div><b>" + r[0] + "</b><span>" + r[1] + "</span></div></li>";
      })
      .join("");
  }

  function buildRatings() {
    var el = document.getElementById("ratingGrid");
    if (!el) return;
    el.innerHTML = PD.ratings
      .map(function (rating) {
        var key = rating[0];
        var value = Number(state.ratings[key] || 0);
        var cells = "";
        for (var i = 1; i <= 5; i++) {
          cells +=
            '<button type="button" data-pk-rating="' +
            key +
            '" data-pk-value="' +
            i +
            '" class="' +
            (value === i ? "is-on" : "") +
            '" aria-label="Rate ' +
            rating[1] +
            " " +
            i +
            ' of 5">' +
            i +
            "</button>";
        }
        return (
          '<div class="pk-rating"><label>' +
          rating[1] +
          '</label><div class="pk-rating__cells">' +
          cells +
          "</div></div>"
        );
      })
      .join("");
  }

  function buildFeedback() {
    var lines = ["RAZEAH — PACK RITUAL FEEDBACK", "Neon Reliquary / Brass Folio", ""];
    PD.ratings.forEach(function (rating) {
      lines.push(rating[1].toUpperCase() + ": " + (state.ratings[rating[0]] || "—") + " / 5");
    });
    if (state.notes.trim()) {
      lines.push("", "NOTES:", state.notes.trim());
    }
    lines.push("", "NEXT: tune these beats in the Godot FolioCeremony.");
    return lines.join("\n");
  }

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

  function copyFeedback() {
    var text = buildFeedback();
    copyText(text)
      .then(function () {
        pageToast("PACK FEEDBACK COPIED · PASTE IT INTO THE CHAT");
      })
      .catch(function () {
        window.prompt("Copy pack ritual feedback", text);
      });
  }

  function setupNotes() {
    var area = document.getElementById("packNotes");
    var saved = document.getElementById("pkSaved");
    if (area) {
      area.value = state.notes;
      area.addEventListener("input", function () {
        state.notes = area.value;
        save(NOTES_KEY, state.notes);
        if (saved) {
          saved.classList.add("is-on");
          clearTimeout(saved._timer);
          saved._timer = setTimeout(function () {
            saved.classList.remove("is-on");
          }, 900);
        }
      });
    }
    var grid = document.getElementById("ratingGrid");
    if (grid) {
      grid.addEventListener("click", function (event) {
        var btn = event.target.closest("[data-pk-rating]");
        if (!btn) return;
        var key = btn.getAttribute("data-pk-rating");
        var value = Number(btn.getAttribute("data-pk-value"));
        state.ratings[key] = state.ratings[key] === value ? 0 : value;
        save(RATINGS_KEY, state.ratings);
        Array.prototype.forEach.call(grid.querySelectorAll('[data-pk-rating="' + key + '"]'), function (b) {
          b.classList.toggle(
            "is-on",
            Number(b.getAttribute("data-pk-value")) === state.ratings[key]
          );
        });
      });
    }
  }

  function buildReveal() {
    var elsR = document.querySelectorAll(".pk-page .reveal");
    if (!("IntersectionObserver" in window) || reduced()) {
      Array.prototype.forEach.call(elsR, function (el) {
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
    Array.prototype.forEach.call(elsR, function (el) {
      io.observe(el);
    });
  }

  function updateScroll() {
    var doc = document.documentElement;
    var max = doc.scrollHeight - window.innerHeight;
    var progress = max > 0 ? Math.min(1, Math.max(0, window.scrollY / max)) : 0;
    var bar = document.getElementById("pkProgress");
    if (bar) bar.style.width = (progress * 100).toFixed(2) + "%";

    var y = window.scrollY + window.innerHeight * 0.5;
    var active = "ritual";
    ["tell", "beats", "ledger", "notes"].forEach(function (id) {
      var el = document.getElementById(id);
      if (el && el.getBoundingClientRect().top + window.scrollY <= y) active = id;
    });
    Array.prototype.forEach.call(document.querySelectorAll("[data-pk-nav]"), function (link) {
      link.classList.toggle("is-active", link.getAttribute("data-pk-nav") === active);
    });
  }

  function onPageClick(event) {
    var sound = event.target.closest("[data-sound-toggle]");
    if (sound) {
      window.RazeahSound.toggle();
      return;
    }
    if (event.target.closest("#packCopyTop") || event.target.closest("#packCopy")) {
      copyFeedback();
      return;
    }
    if (event.target.closest("#packMotion")) {
      setMotion(motion === "reduced" ? "full" : "reduced", true);
      return;
    }
    if (event.target.closest("#pkTheaterOpen")) {
      openTheater();
      return;
    }
    if (event.target.closest("#pkTheaterClose")) {
      closeTheater();
      return;
    }
  }

  function onKeydown(event) {
    var tag = (event.target && event.target.tagName ? event.target.tagName : "").toLowerCase();
    var typing = tag === "input" || tag === "textarea" || tag === "select";
    if (event.key === "Escape") {
      if (els.zoom && els.zoom.classList.contains("is-open")) {
        closeZoom();
        return;
      }
      if (document.getElementById("pkFrame").classList.contains("is-theater")) {
        closeTheater();
        return;
      }
    }
    if (typing) return;

    var slot = event.target.closest ? event.target.closest(".pk-card-slot") : null;
    if (slot && (event.key === "Enter" || event.key === " ")) {
      event.preventDefault();
      var i = indexOfSlot(slot);
      if (state.revealed[i]) openZoom(i);
      else if (state.stage === "ready" || state.stage === "flipping") flip(i, false);
      return;
    }
    if (event.key === "s" || event.key === "S") {
      if (state.stage !== "sealed" && state.stage !== "summary") {
        event.preventDefault();
        skipToSummary();
      }
      return;
    }
    if (event.key === "r" || event.key === "R") {
      if (state.stage === "ready" || state.stage === "flipping" || state.stage === "dealing") {
        event.preventDefault();
        revealAll();
      }
      return;
    }
    if (event.key === "a" || event.key === "A") {
      if (state.stage === "ready" || state.stage === "flipping") {
        event.preventDefault();
        toggleAuto();
      }
      return;
    }
    if (event.key === "Enter" || event.key === " ") {
      if (
        state.stage === "sealed" &&
        (!event.target.closest ||
          !event.target.closest("button, a, input, textarea, select"))
      ) {
        event.preventDefault();
        crack();
      }
    }
    if (event.key === "ArrowLeft" || event.key === "ArrowRight") {
      var slots = Array.prototype.slice.call(els.fan.querySelectorAll(".pk-card-slot"));
      if (!slots.length) return;
      var current = document.activeElement && document.activeElement.closest
        ? document.activeElement.closest(".pk-card-slot")
        : null;
      var idx = current ? slots.indexOf(current) : -1;
      var next = event.key === "ArrowRight" ? Math.min(slots.length - 1, idx + 1) : Math.max(0, idx - 1);
      event.preventDefault();
      try {
        slots[next].focus({ preventScroll: true });
      } catch (err) {}
    }
  }

  /* ------------------------------------------------------------------ */
  /* boot                                                                */
  /* ------------------------------------------------------------------ */

  function init() {
    state.set = PD.folios[0].setBefore;
    buildStage();
    buildTellGrid();
    buildBeats();
    buildReject();
    buildRatings();
    setupNotes();
    startFolio(0, true);
    setMotion(motion, false);
    if (window.RazeahSound) window.RazeahSound.sync();
    buildReveal();
    updateScroll();
    document.addEventListener("click", onPageClick);
    document.addEventListener("keydown", onKeydown);
    window.addEventListener("scroll", updateScroll, { passive: true });
    window.addEventListener("resize", updateScroll);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();

/* Razeah — Packs + Table UX review.
 * Two live prototypes: the pack ceremony and the recommended table.
 * The prototypes are intentionally simplified; the review copy and the
 * implementation map carry the real contract.
 */
(function () {
  "use strict";

  var $ = function (sel, root) {
    return (root || document).querySelector(sel);
  };
  var $$ = function (sel, root) {
    return Array.prototype.slice.call((root || document).querySelectorAll(sel));
  };

  var CARD_IMAGES = {
    cinderHound: "assets/cards/ember_cinder_hound.png",
    ashMoth: "assets/cards/ember_ash_moth.png",
    emberScout: "assets/cards/ember_ember_scout.png",
    tidecall: "assets/cards/tide_tidecall.png",
    ninefoldSeal: "assets/cards/neutral_ninefold_seal.png",
    boneOrchard: "assets/cards/verdant_bone_orchard.png",
    hollowLantern: "assets/cards/umbra_hollow_lantern.png",
    brambleWall: "assets/cards/verdant_bramble_wall.png",
    quietLedger: "assets/cards/neutral_quiet_ledger.png"
  };

  var CARD_INFO = {
    cinderHound: {
      name: "Cinder Hound",
      type: "monster",
      subtype: "Beast",
      attribute: "EMBER",
      rarity: "common",
      atk: 1200,
      def: 800,
      text: "KINDLE: Deal 200 damage."
    },
    ashMoth: {
      name: "Ash Moth",
      type: "monster",
      subtype: "Beast",
      attribute: "EMBER",
      rarity: "common",
      atk: 600,
      def: 400,
      text: "ECHO: Deal 100 damage."
    },
    emberScout: {
      name: "Ember Scout",
      type: "monster",
      subtype: "Beast",
      attribute: "EMBER",
      rarity: "common",
      atk: 1600,
      def: 1000,
      text: "FLEET."
    },
    tidecall: {
      name: "Tidecall",
      type: "spell",
      subtype: "Normal",
      attribute: "TIDE",
      rarity: "uncommon",
      atk: null,
      def: null,
      text: "Draw 1. If you control a TIDE monster, draw 1 more."
    },
    ninefoldSeal: {
      name: "Ninefold Seal",
      type: "trap",
      subtype: "Counter",
      attribute: "NEUTRAL",
      rarity: "rare",
      atk: null,
      def: null,
      text: "Negate an attack, then banish the attacker."
    },
    boneOrchard: {
      name: "Bone Orchard",
      type: "trap",
      subtype: "Continuous",
      attribute: "VERDANT",
      rarity: "uncommon",
      atk: null,
      def: null,
      text: "When a monster is destroyed, summon a 500/500 token."
    },
    hollowLantern: {
      name: "Hollow Lantern",
      type: "spell",
      subtype: "Continuous",
      attribute: "UMBRA",
      rarity: "uncommon",
      atk: null,
      def: null,
      text: "Monsters in this lane gain 200 ATK."
    },
    brambleWall: {
      name: "Bramble Wall",
      type: "monster",
      subtype: "Construct",
      attribute: "VERDANT",
      rarity: "common",
      atk: 300,
      def: 2200,
      text: "No effect."
    },
    quietLedger: {
      name: "The Quiet Ledger",
      type: "spell",
      subtype: "Normal",
      attribute: "NEUTRAL",
      rarity: "rare",
      atk: null,
      def: null,
      text: "Draw 2. At Dusk, discard 1."
    }
  };

  var RARITY_FALLBACK = {
    common: { label: "COMMON", pips: 1, color: "#9aa0b5" },
    uncommon: { label: "UNCOMMON", pips: 2, color: "#7dffb2" },
    rare: { label: "RARE", pips: 3, color: "#ffcc55" },
    legendary: { label: "LEGENDARY", pips: 4, color: "#ff3fa4" }
  };

  var ROMAN = ["I", "II", "III"];
  var toastTimer = null;

  function reduceMotion() {
    return window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  }

  function fmt(value) {
    return String(value).replace(/\B(?=(\d{3})+(?!\d))/g, ",");
  }

  function escapeHtml(value) {
    return String(value).replace(/[&<>"']/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c];
    });
  }

  function showToast(text) {
    var el = $("#uxToast");
    if (!el) return;
    el.textContent = text;
    el.classList.add("is-show");
    clearTimeout(toastTimer);
    toastTimer = setTimeout(function () {
      el.classList.remove("is-show");
    }, 2200);
  }

  function rarity(key) {
    var info = CARD_INFO[key];
    var packs = window.RAZEAH_PACKS && window.RAZEAH_PACKS.rarity;
    return (packs && packs[info.rarity]) || RARITY_FALLBACK[info.rarity] || RARITY_FALLBACK.common;
  }

  function typeLabel(key) {
    var info = CARD_INFO[key];
    return info.type.toUpperCase() + " · " + info.attribute + " · " + info.subtype.toUpperCase();
  }

  /* ================================================================== */
  /* fit helpers                                                         */
  /* ================================================================== */

  function fitFixed(wrap, stage, width, height) {
    if (!wrap || !stage) return;
    var available = Math.max(1, wrap.clientWidth - 2);
    var scale = Math.min(1, available / width);
    stage.style.transformOrigin = "top center";
    stage.style.transform = "scale(" + scale + ")";
    wrap.style.height = Math.ceil(height * scale) + "px";
  }

  function fitPack() {
    fitFixed($("#packWrap"), $("#packStage"), 960, 540);
  }

  function fitTable() {
    fitFixed($("#uxTableWrap"), $("#uxTable"), 1440, 900);
  }

  /* ================================================================== */
  /* pack lab                                                            */
  /* ================================================================== */

  var packState = {
    mode: "rip",
    opened: false,
    busy: false,
    cards: [],
    revealed: [],
    timers: []
  };

  var PACK_CARDS = ["ashMoth", "cinderHound", "tidecall", "ninefoldSeal", "brambleWall"];

  function later(fn, ms) {
    var timer = setTimeout(fn, reduceMotion() ? 0 : ms);
    packState.timers.push(timer);
    return timer;
  }

  function clearPackTimers() {
    packState.timers.forEach(function (timer) {
      clearTimeout(timer);
    });
    packState.timers = [];
  }

  function packObjectMarkup() {
    if (packState.mode === "case") {
      return (
        '<span class="ux-pack-object__lid"></span>' +
        '<span class="ux-pack-object__clasp"></span>' +
        '<span class="ux-pack-object__label">RELIQUARY CASE</span>' +
        '<span class="ux-pack-object__seal">R</span>' +
        '<span class="ux-pack-object__sub">5 CARDS · PROVENANCE 25</span>'
      );
    }
    if (packState.mode === "stack") {
      return (
        '<span class="ux-pack-stackback"></span>' +
        '<span class="ux-pack-stackback"></span>' +
        '<span class="ux-pack-stackback"></span>' +
        '<span class="ux-pack-object__label">PACK 01</span>' +
        '<span class="ux-pack-object__seal">R</span>' +
        '<span class="ux-pack-object__sub">CLICK THE TOP CARD</span>'
      );
    }
    return (
      '<span class="ux-pack-object__tear"></span>' +
      '<span class="ux-pack-object__label">PACK 01 · BRASS</span>' +
      '<span class="ux-pack-object__seal">R</span>' +
      '<span class="ux-pack-object__sub">5 CARDS · RARE GUARANTEED</span>'
    );
  }

  function renderPackObject() {
    var object = $("#packObject");
    if (!object) return;
    object.className = "ux-pack-object ux-pack-object--" + packState.mode;
    object.innerHTML = packObjectMarkup();
    object.setAttribute("aria-label", "Open the sealed pack");
    object.setAttribute("role", "button");
    object.setAttribute("tabindex", "0");
    object.classList.toggle("is-open", packState.opened);
    object.onclick = openPack;
    object.onkeydown = function (event) {
      if (event.key === "Enter" || event.key === " ") {
        event.preventDefault();
        openPack();
      }
    };
  }

  function packCardMarkup(key, index, x, y, rotation, z) {
    var info = CARD_INFO[key];
    var tell = rarity(key);
    var pips = "";
    for (var i = 0; i < tell.pips; i++) {
      pips += "<i></i>";
    }
    return (
      '<div class="ux-pack-card" data-index="' + index + '" data-key="' + key + '" role="button" tabindex="0" ' +
      'aria-label="Reveal ' + escapeHtml(info.name) + ', ' + escapeHtml(tell.label) + '" ' +
      'style="--x:' + x + 'px;--y:' + y + 'px;--r:' + rotation + 'deg;--i:' + index + ';z-index:' + z + '">' +
      '<div class="ux-pack-card__inner">' +
      '<div class="ux-pack-card__face ux-pack-card__face--back">' +
      '<span class="ux-pack-card__backring"></span>' +
      '<span class="ux-pack-card__backicon">R</span>' +
      '<span class="ux-tell" data-rarity="' + info.rarity + '">' +
      '<span class="ux-tell__pips">' + pips + "</span>" +
      '<span class="ux-tell__label">' + tell.label + " · " + tell.pips + (tell.pips > 1 ? " PIPS" : " PIP") + "</span>" +
      "</span>" +
      "</div>" +
      '<div class="ux-pack-card__face ux-pack-card__face--front">' +
      '<img src="' + CARD_IMAGES[key] + '" alt="' + escapeHtml(info.name) + '" />' +
      "</div>" +
      "</div>" +
      '<span class="ux-pack-card__stamp">NEW</span>' +
      "</div>"
    );
  }

  function renderPackCards() {
    var fan = $("#packFan");
    if (!fan) return;
    fan.innerHTML = "";
    packState.cards.forEach(function (key, index) {
      var x = 0;
      var y = 0;
      var rotation = 0;
      var z = 10 + index;
      if (packState.mode === "rip") {
        x = [-200, -100, 0, 100, 200][index];
        y = [30, 10, 0, 10, 30][index];
        rotation = [-12, -6, 0, 6, 12][index];
      } else if (packState.mode === "case") {
        x = [-280, -140, 0, 140, 280][index];
        y = 0;
        rotation = 0;
      } else {
        x = 0;
        y = -index * 3;
        rotation = (index - 2) * 2;
      }
      fan.insertAdjacentHTML("beforeend", packCardMarkup(key, index, x, y, rotation, z));
    });

    $$(".ux-pack-card", fan).forEach(function (card) {
      card.addEventListener("click", function () {
        revealPackCard(Number(card.dataset.index), card);
      });
      card.addEventListener("keydown", function (event) {
        if (event.key === "Enter" || event.key === " ") {
          event.preventDefault();
          revealPackCard(Number(card.dataset.index), card);
        }
      });
    });
  }

  function openPack() {
    if (packState.opened || packState.busy) return;
    packState.opened = true;
    var object = $("#packObject");
    if (object) object.classList.add("is-open");
    var status = $("#packStatus");
    var hint = $("#packHint");
    if (status) status.textContent = "OPENING · THE CONTAINER FAILS";
    if (hint) hint.textContent = "The cards are already committed. The ceremony only reveals them.";
    later(dealPack, 520);
  }

  function dealPack() {
    packState.cards = PACK_CARDS.slice();
    packState.revealed = packState.cards.map(function () {
      return false;
    });
    renderPackCards();
    var object = $("#packObject");
    if (object) later(function () { object.classList.add("is-dealt"); }, 260);
    var status = $("#packStatus");
    var hint = $("#packHint");
    if (status) status.textContent = "5 CARDS · CLICK EACH CARD";
    if (hint) hint.textContent = "Hover a back for the tell. Every tell is exact.";
  }

  function revealPackCard(index, card) {
    if (!packState.opened || packState.busy || packState.revealed[index]) return;
    packState.busy = true;
    card.classList.add("is-busy");
    card.classList.add("is-revealed");
    var status = $("#packStatus");
    if (status) status.textContent = "TURNING · " + CARD_INFO[packState.cards[index]].name.toUpperCase();
    later(function () {
      packState.revealed[index] = true;
      packState.busy = false;
      card.classList.remove("is-busy");
      var count = packState.revealed.filter(Boolean).length;
      if (status) status.textContent = count + " OF 5 REVEALED";
      var hint = $("#packHint");
      if (hint) {
        hint.textContent =
          count >= 5
            ? "All cards revealed. The ledger keeps the fan on screen."
            : "Click the next card. The result was committed before the first frame.";
      }
      if (packState.mode === "stack") {
        var revealedCount = count - 1;
        card.style.setProperty("--x", -250 + revealedCount * 46 + "px");
        card.style.setProperty("--y", "82px");
        card.style.setProperty("--r", "-8deg");
        card.style.zIndex = String(5 + revealedCount);
      }
      if (count >= 5) later(showPackLedger, 360);
    }, 470);
  }

  function showPackLedger() {
    var ledger = $("#packLedger");
    if (!ledger) return;
    ledger.hidden = false;
    ledger.innerHTML =
      "<b>LEDGER · COMMITTED</b>" +
      "<span>5 CARDS</span>" +
      "<span>3 NEW</span>" +
      "<span>1 RARE</span>" +
      "<span>SET 12 / 16</span>" +
      '<button type="button" data-pack-reset>OPEN ANOTHER</button>';
    var status = $("#packStatus");
    var hint = $("#packHint");
    if (status) status.textContent = "LEDGER · 5 OF 5 REVEALED";
    if (hint) hint.textContent = "The cards stay clickable. The pack is gone; the result is not.";
  }

  function resetPackLab() {
    clearPackTimers();
    packState.opened = false;
    packState.busy = false;
    packState.cards = [];
    packState.revealed = [];
    var fan = $("#packFan");
    if (fan) fan.innerHTML = "";
    var ledger = $("#packLedger");
    if (ledger) {
      ledger.hidden = true;
      ledger.innerHTML = "";
    }
    var status = $("#packStatus");
    var hint = $("#packHint");
    if (status) status.textContent = "SEALED · CLICK THE PACK";
    if (hint) hint.textContent = "The result is committed before the first frame. The tell is exact.";
    renderPackObject();
  }

  function setPackMode(mode) {
    packState.mode = mode;
    $$("[data-packmode]").forEach(function (button) {
      var on = button.getAttribute("data-packmode") === mode;
      button.classList.toggle("is-on", on);
      button.setAttribute("aria-selected", on ? "true" : "false");
    });
    resetPackLab();
  }

  /* ================================================================== */
  /* table lab                                                           */
  /* ================================================================== */

  function initialBoard() {
    return {
      "1|backrow|0": { key: "hollowLantern", faceDown: true },
      "1|monster|0": { key: "emberScout" },
      "1|monster|1": { key: "brambleWall" },
      "1|backrow|2": { key: "ninefoldSeal", faceDown: true },
      "0|monster|0": { key: "cinderHound" }
    };
  }

  function initialLog() {
    return [
      { text: "The Damp Warden sets a card in Lane III." },
      { text: "You call Cinder Hound to Lane I." },
      { text: "Intent read: TIDECALL → Lane II.", hot: true },
      { text: "Your move. Drag a card or select it." }
    ];
  }

  var tableState = {
    hand: [],
    board: {},
    selected: null,
    inspected: "cinderHound",
    panelTab: "log",
    log: [],
    playerResolve: 4000,
    wardenResolve: 3180,
    dragging: null,
    suppressClickUntil: 0
  };

  function resetTableState() {
    tableState.hand = ["ashMoth", "emberScout", "tidecall", "ninefoldSeal", "brambleWall"];
    tableState.board = initialBoard();
    tableState.selected = null;
    tableState.inspected = "cinderHound";
    tableState.panelTab = "log";
    tableState.log = initialLog();
    tableState.playerResolve = 4000;
    tableState.wardenResolve = 3180;
    tableState.dragging = null;
    tableState.suppressClickUntil = 0;
  }

  function slotSelector(owner, zone, lane) {
    return '.ux-slot[data-owner="' + owner + '"][data-zone="' + zone + '"][data-lane="' + lane + '"]';
  }

  function slotFromBoard(owner, zone, lane) {
    return $(slotSelector(owner, zone, lane));
  }

  function boardCardAt(owner, zone, lane) {
    return tableState.board[owner + "|" + zone + "|" + lane] || null;
  }

  function makeSlot(owner, zone, lane) {
    var slot = document.createElement("div");
    slot.className = "ux-slot";
    slot.dataset.owner = String(owner);
    slot.dataset.zone = zone;
    slot.dataset.lane = String(lane);
    slot.tabIndex = 0;
    slot.setAttribute("role", "button");
    var card = boardCardAt(owner, zone, lane);
    if (card) {
      slot.dataset.filled = "1";
      slot.appendChild(makeBoardCard(owner, zone, lane, card));
    }
    slot.setAttribute(
      "aria-label",
      (owner === 0 ? "Your " : "Warden ") +
        (zone === "monster" ? "monster lane " : "backrow lane ") +
        ROMAN[lane] +
        ", " +
        (card ? CARD_INFO[card.key].name : "empty")
    );
    slot.addEventListener("click", function (event) {
      if (event.target.closest(".ux-board-card")) return;
      onSlotClick(slot);
    });
    slot.addEventListener("keydown", function (event) {
      if (event.key !== "Enter" && event.key !== " ") return;
      event.preventDefault();
      if (card && owner === 0 && zone === "monster") {
        onBoardCardClick(0, zone, lane, card);
        return;
      }
      if (card && owner === 1) {
        onBoardCardClick(1, zone, lane, card);
        return;
      }
      onSlotClick(slot);
    });
    return slot;
  }

  function makeBoardCard(owner, zone, lane, card) {
    var info = CARD_INFO[card.key];
    var el = document.createElement("div");
    el.className = "ux-board-card" + (card.faceDown ? " is-facedown" : "");
    el.dataset.owner = String(owner);
    el.dataset.zone = zone;
    el.dataset.lane = String(lane);
    el.dataset.key = card.key;
    el.innerHTML =
      '<img src="' + (card.faceDown ? "assets/cards/back.png" : CARD_IMAGES[card.key]) + '" alt="' +
      escapeHtml(card.faceDown ? "Set card" : info.name) + '" />' +
      (card.faceDown ? '<span class="ux-setbadge">SET</span>' : "");
    el.addEventListener("click", function (event) {
      event.stopPropagation();
      if (Date.now() < tableState.suppressClickUntil) return;
      onBoardCardClick(owner, zone, lane, card);
    });
    if (owner === 0 && zone === "monster") {
      el.addEventListener("pointerdown", function (event) {
        beginPointer(event, el, { kind: "board", lane: lane, key: card.key });
      });
    }
    return el;
  }

  function renderBoard() {
    var wardenMat = $(".ux-mat--warden", $("#uxBoard"));
    var playerMat = $(".ux-mat--player", $("#uxBoard"));
    if (!wardenMat || !playerMat) return;
    [wardenMat, playerMat].forEach(function (mat) {
      var old = $(".ux-lanes", mat);
      if (old) old.remove();
    });
    [[1, wardenMat], [0, playerMat]].forEach(function (pair) {
      var owner = pair[0];
      var mat = pair[1];
      var lanes = document.createElement("div");
      lanes.className = "ux-lanes";
      for (var lane = 0; lane < 3; lane++) {
        var laneEl = document.createElement("div");
        laneEl.className = "ux-lane";
        laneEl.appendChild(makeSlot(owner, "backrow", lane));
        laneEl.appendChild(makeSlot(owner, "monster", lane));
        lanes.appendChild(laneEl);
      }
      mat.appendChild(lanes);
    });
  }

  function renderHand() {
    var hand = $("#uxHand");
    if (!hand) return;
    hand.innerHTML = "";
    tableState.hand.forEach(function (key) {
      var info = CARD_INFO[key];
      var el = document.createElement("div");
      el.className = "ux-hand-card";
      el.dataset.key = key;
      el.dataset.type = info.type;
      el.tabIndex = 0;
      el.setAttribute("role", "button");
      el.setAttribute("aria-label", info.name + ". Drag to a legal zone, or select and click a zone.");
      el.innerHTML =
        '<div class="ux-hand-clip"><img src="' + CARD_IMAGES[key] + '" alt="' + escapeHtml(info.name) + '" /></div>';
      el.addEventListener("click", function () {
        if (Date.now() < tableState.suppressClickUntil) return;
        selectHand(key);
      });
      el.addEventListener("keydown", function (event) {
        if (event.key === "Enter" || event.key === " ") {
          event.preventDefault();
          selectHand(key);
        }
      });
      el.addEventListener("pointerdown", function (event) {
        beginPointer(event, el, { kind: "hand", key: key });
      });
      hand.appendChild(el);
    });
  }

  function clearZoneHighlights() {
    $$(".ux-slot.is-legal, .ux-slot.is-target, .ux-slot.is-over").forEach(function (slot) {
      slot.classList.remove("is-legal", "is-target", "is-over");
    });
  }

  function isLegalHandDrop(key, slot) {
    if (!slot || slot.dataset.owner !== "0" || slot.dataset.filled === "1") return false;
    var type = CARD_INFO[key].type;
    return type === "monster" ? slot.dataset.zone === "monster" : slot.dataset.zone === "backrow";
  }

  function isLegalTarget(slot) {
    return !!slot && slot.dataset.owner === "1" && slot.dataset.zone === "monster" && slot.dataset.filled === "1";
  }

  function highlightForHand(key) {
    clearZoneHighlights();
    $$(".ux-slot").forEach(function (slot) {
      if (isLegalHandDrop(key, slot)) slot.classList.add("is-legal");
    });
  }

  function highlightForBoard() {
    clearZoneHighlights();
    $$(".ux-slot").forEach(function (slot) {
      if (isLegalTarget(slot)) slot.classList.add("is-target");
    });
  }

  function highlightForSelection() {
    if (!tableState.selected) {
      clearZoneHighlights();
      return;
    }
    if (tableState.selected.kind === "hand") highlightForHand(tableState.selected.key);
    else highlightForBoard();
  }

  function updateDockHint(text) {
    var hint = $("#uxDockHint");
    if (!hint) return;
    if (text) {
      hint.textContent = text;
      return;
    }
    if (tableState.dragging) {
      hint.textContent = tableState.dragging.kind === "board"
        ? "DROP ON A GLOWING ENEMY MONSTER"
        : "DROP ON A GLOWING ZONE · SHIFT = SET";
      return;
    }
    if (!tableState.selected) {
      hint.textContent = "SELECT OR DRAG A CARD";
      return;
    }
    if (tableState.selected.kind === "board") {
      hint.textContent = "STRIKE A GLOWING ENEMY MONSTER";
      return;
    }
    var info = CARD_INFO[tableState.selected.key];
    hint.textContent = info.type === "monster"
      ? info.name.toUpperCase() + " · DROP ON A MONSTER LANE · SHIFT = SET"
      : info.name.toUpperCase() + " · DROP ON A BACKROW LANE · SHIFT = SET";
  }

  function selectHand(key) {
    if (tableState.selected && tableState.selected.kind === "hand" && tableState.selected.key === key) {
      clearSelection();
      return;
    }
    tableState.selected = { kind: "hand", key: key };
    tableState.inspected = key;
    $$(".ux-hand-card").forEach(function (card) {
      card.classList.toggle("is-selected", card.dataset.key === key);
    });
    highlightForSelection();
    updateDockHint();
    if (tableState.panelTab === "actions" || tableState.panelTab === "inspect") renderPanel();
  }

  function selectBoard(lane, key) {
    if (tableState.selected && tableState.selected.kind === "board" && tableState.selected.lane === lane) {
      clearSelection();
      return;
    }
    tableState.selected = { kind: "board", lane: lane, key: key };
    tableState.inspected = key;
    $$(".ux-hand-card").forEach(function (card) {
      card.classList.remove("is-selected");
    });
    highlightForSelection();
    updateDockHint();
    if (tableState.panelTab === "actions" || tableState.panelTab === "inspect") renderPanel();
  }

  function clearSelection() {
    tableState.selected = null;
    $$(".ux-hand-card").forEach(function (card) {
      card.classList.remove("is-selected");
    });
    clearZoneHighlights();
    updateDockHint();
    if (tableState.panelTab === "actions") renderPanel();
  }

  function onSlotClick(slot) {
    if (Date.now() < tableState.suppressClickUntil) return;
    if (!tableState.selected) return;
    if (tableState.selected.kind === "hand") {
      if (isLegalHandDrop(tableState.selected.key, slot)) {
        playCard(tableState.selected.key, slot, false);
      }
      return;
    }
    if (tableState.selected.kind === "board" && isLegalTarget(slot)) {
      attack(Number(slot.dataset.lane));
    }
  }

  function onBoardCardClick(owner, zone, lane, card) {
    tableState.inspected = card.key;
    if (owner === 0 && zone === "monster") {
      selectBoard(lane, card.key);
      return;
    }
    tableState.panelTab = "inspect";
    renderPanel();
  }

  function playCard(key, slot, set) {
    if (!isLegalHandDrop(key, slot)) return false;
    var lane = Number(slot.dataset.lane);
    var zone = slot.dataset.zone;
    var info = CARD_INFO[key];
    tableState.board["0|" + zone + "|" + lane] = { key: key, faceDown: !!set, set: !!set };
    tableState.hand = tableState.hand.filter(function (cardKey) {
      return cardKey !== key;
    });
    tableState.inspected = key;
    tableState.log.push({
      text: set
        ? "You set " + info.name + " in Lane " + ROMAN[lane] + "."
        : info.type === "monster"
          ? "You call " + info.name + " to Lane " + ROMAN[lane] + "."
          : "You play " + info.name + " in Lane " + ROMAN[lane] + "."
    });
    clearSelection();
    renderHand();
    renderBoard();
    renderPanel();
    updateScore();
    var freshSlot = slotFromBoard(0, zone, lane);
    if (freshSlot) {
      freshSlot.classList.add("is-flash");
      setTimeout(function () {
        freshSlot.classList.remove("is-flash");
      }, 320);
    }
    showToast(info.name + " · " + (set ? "set" : "played") + " · Lane " + ROMAN[lane]);
    return true;
  }

  function attack(lane) {
    if (!tableState.selected || tableState.selected.kind !== "board") return;
    var source = boardCardAt(0, "monster", tableState.selected.lane);
    var target = boardCardAt(1, "monster", lane);
    if (!source || !target) return;
    var sourceInfo = CARD_INFO[source.key];
    var targetInfo = CARD_INFO[target.key];
    tableState.wardenResolve = Math.max(0, tableState.wardenResolve - 1200);
    tableState.log.push({
      text: sourceInfo.name + " strikes " + targetInfo.name + " for 1,200.",
      hot: true
    });
    clearSelection();
    renderPanel();
    updateScore();
    var targetSlot = slotFromBoard(1, "monster", lane);
    if (targetSlot) {
      targetSlot.classList.add("is-flash");
      setTimeout(function () {
        targetSlot.classList.remove("is-flash");
      }, 320);
    }
    showToast(sourceInfo.name + " strikes " + targetInfo.name + " · 1,200");
  }

  function updateScore() {
    var you = $(".ux-score--you b");
    var warden = $(".ux-score--warden b");
    if (you) you.textContent = fmt(tableState.playerResolve);
    if (warden) warden.textContent = fmt(tableState.wardenResolve);
  }

  function emptyLanes(owner, zone) {
    var out = [];
    for (var lane = 0; lane < 3; lane++) {
      if (!boardCardAt(owner, zone, lane)) out.push(lane);
    }
    return out;
  }

  function renderPanel() {
    $$(".ux-paneltabs button").forEach(function (button) {
      button.classList.toggle("is-on", button.getAttribute("data-ptab") === tableState.panelTab);
    });
    var body = $("#uxPanelBody");
    if (!body) return;
    if (tableState.panelTab === "log") {
      body.innerHTML = tableState.log
        .map(function (entry) {
          return '<div class="ux-logline' + (entry.hot ? " is-hot" : "") + '">' + escapeHtml(entry.text) + "</div>";
        })
        .join("");
      body.scrollTop = body.scrollHeight;
      return;
    }
    if (tableState.panelTab === "inspect") {
      var key = (tableState.selected && tableState.selected.key) || tableState.inspected;
      if (!key) {
        body.innerHTML = '<p class="ux-inspect-empty">Select a card to inspect it.</p>';
        return;
      }
      var info = CARD_INFO[key];
      var stats = info.type === "monster"
        ? "ATK " + fmt(info.atk) + " · DEF " + fmt(info.def)
        : typeLabel(key);
      body.innerHTML =
        '<div class="ux-inspect-card">' +
        "<b>" + escapeHtml(info.name) + "</b>" +
        "<span>" + escapeHtml(stats) + "</span>" +
        "<p>" + escapeHtml(info.text) + "</p>" +
        "</div>";
      return;
    }
    var actions = [];
    if (tableState.selected && tableState.selected.kind === "hand") {
      var selectedKey = tableState.selected.key;
      var selectedInfo = CARD_INFO[selectedKey];
      if (selectedInfo.type === "monster") {
        emptyLanes(0, "monster").forEach(function (lane) {
          actions.push(
            '<button class="ux-actionbtn" type="button" data-panel-action="call" data-key="' + selectedKey +
            '" data-lane="' + lane + '">CALL · LANE ' + ROMAN[lane] + "</button>"
          );
        });
        emptyLanes(0, "monster").forEach(function (lane) {
          actions.push(
            '<button class="ux-actionbtn" type="button" data-panel-action="set" data-key="' + selectedKey +
            '" data-lane="' + lane + '">SET · LANE ' + ROMAN[lane] + "</button>"
          );
        });
      } else {
        emptyLanes(0, "backrow").forEach(function (lane) {
          actions.push(
            '<button class="ux-actionbtn" type="button" data-panel-action="call" data-key="' + selectedKey +
            '" data-lane="' + lane + '">PLAY · LANE ' + ROMAN[lane] + "</button>"
          );
        });
        emptyLanes(0, "backrow").forEach(function (lane) {
          actions.push(
            '<button class="ux-actionbtn" type="button" data-panel-action="set" data-key="' + selectedKey +
            '" data-lane="' + lane + '">SET · LANE ' + ROMAN[lane] + "</button>"
          );
        });
      }
    } else if (tableState.selected && tableState.selected.kind === "board") {
      for (var lane = 0; lane < 3; lane++) {
        var target = boardCardAt(1, "monster", lane);
        if (target) {
          actions.push(
            '<button class="ux-actionbtn" type="button" data-panel-action="attack" data-lane="' + lane +
            '">STRIKE · ' + escapeHtml(CARD_INFO[target.key].name.toUpperCase()) + " · LANE " + ROMAN[lane] + "</button>"
          );
        }
      }
    }
    if (!actions.length) {
      body.innerHTML = '<p class="ux-inspect-empty">Select a card or drag it to a zone.</p>';
    } else {
      body.innerHTML = actions.join("");
    }
    body.insertAdjacentHTML(
      "beforeend",
      '<button class="ux-actionbtn" type="button" data-panel-action="end">END PHASE · [E]</button>'
    );
  }

  function setPanelMode(mode) {
    var table = $("#uxTable");
    if (!table) return;
    table.dataset.panel = mode;
    table.classList.remove("is-panel-hidden");
    if (mode === "overlay") table.classList.add("is-panel-open");
    else table.classList.remove("is-panel-open");
    $$("[data-panel-mode]").forEach(function (button) {
      button.classList.toggle("is-on", button.getAttribute("data-panel-mode") === mode);
    });
    updatePanelButton();
  }

  function updatePanelButton() {
    var table = $("#uxTable");
    var button = $("#uxPanelButton");
    if (!table || !button) return;
    var mode = table.dataset.panel;
    var open = mode === "overlay" ? table.classList.contains("is-panel-open") : !table.classList.contains("is-panel-hidden");
    var glyph = mode === "overlay" ? (open ? "×" : "›") : (open ? "‹" : "›");
    button.innerHTML = "PANEL <span>" + glyph + "</span>";
    button.setAttribute("aria-expanded", open ? "true" : "false");
    var pin = $("#uxPinButton");
    if (pin) {
      pin.classList.toggle("is-on", mode === "pinned");
      pin.textContent = mode === "pinned" ? "PINNED" : "PIN";
    }
  }

  function togglePanel() {
    var table = $("#uxTable");
    if (!table) return;
    if (table.dataset.panel === "overlay") {
      table.classList.toggle("is-panel-open");
    } else {
      table.classList.toggle("is-panel-hidden");
    }
    updatePanelButton();
  }

  function closePanel() {
    var table = $("#uxTable");
    if (!table) return;
    if (table.dataset.panel === "overlay") table.classList.remove("is-panel-open");
    else table.classList.add("is-panel-hidden");
    updatePanelButton();
  }

  function setHandMode(mode) {
    var table = $("#uxTable");
    if (!table) return;
    table.dataset.hand = mode;
    $$("[data-hand-mode]").forEach(function (button) {
      button.classList.toggle("is-on", button.getAttribute("data-hand-mode") === mode);
    });
    updateDockHint();
  }

  function resetTable() {
    resetTableState();
    setHandMode("tray");
    setPanelMode("overlay");
    renderHand();
    renderBoard();
    renderPanel();
    updateScore();
    updateDockHint();
    showToast("Table reset.");
  }

  function renderTable() {
    renderHand();
    renderBoard();
    renderPanel();
    updateScore();
    updateDockHint();
  }

  /* ================================================================== */
  /* drag + drop                                                         */
  /* ================================================================== */

  function beginPointer(event, sourceEl, info) {
    if (event.button !== 0 && event.pointerType === "mouse") return;
    var table = $("#uxTable");
    if (info.kind === "hand" && table && table.dataset.panel === "overlay" && table.classList.contains("is-panel-open")) {
      table.classList.remove("is-panel-open");
      updatePanelButton();
    }
    if (info.kind === "hand") highlightForHand(info.key);
    else if (info.kind === "board") highlightForBoard();
    var startX = event.clientX;
    var startY = event.clientY;
    var originRect = sourceEl.getBoundingClientRect();
    var drag = null;

    function onMove(moveEvent) {
      var dx = moveEvent.clientX - startX;
      var dy = moveEvent.clientY - startY;
      if (!drag && Math.sqrt(dx * dx + dy * dy) < 6) return;
      if (!drag) {
        drag = startDrag(sourceEl, info, originRect);
        if (!drag) return;
      }
      moveEvent.preventDefault();
      drag.clone.style.left = moveEvent.clientX - drag.width / 2 + "px";
      drag.clone.style.top = moveEvent.clientY - drag.height / 2 + "px";
      drag.set = !!moveEvent.shiftKey;
      drag.clone.dataset.set = drag.set ? "1" : "0";
      var slot = slotAtPoint(moveEvent.clientX, moveEvent.clientY);
      var legal = slot && dropIsLegal(drag, slot);
      $$(".ux-slot.is-over").forEach(function (node) {
        node.classList.remove("is-over");
      });
      if (legal) slot.classList.add("is-over");
      drag.clone.classList.toggle("is-legal", !!legal && drag.kind === "hand");
      drag.clone.classList.toggle("is-target", !!legal && drag.kind === "board");
      updateDockHint(
        legal
          ? drag.kind === "board"
            ? "RELEASE TO STRIKE"
            : "RELEASE TO " + (drag.set ? "SET" : "PLAY")
          : drag.kind === "board"
            ? "DROP ON A GLOWING ENEMY MONSTER"
            : "DROP ON A GLOWING ZONE · SHIFT = SET"
      );
    }

    function onUp(upEvent) {
      document.removeEventListener("pointermove", onMove);
      document.removeEventListener("pointerup", onUp);
      document.removeEventListener("pointercancel", onUp);
      if (!drag) {
        updateDockHint();
        return;
      }
      tableState.suppressClickUntil = Date.now() + 260;
      var slot = slotAtPoint(upEvent.clientX, upEvent.clientY);
      var legal = slot && dropIsLegal(drag, slot);
      var clone = drag.clone;
      var source = drag.sourceEl;
      var infoKind = drag.kind;
      var key = drag.key;
      var lane = drag.lane;
      var set = !!drag.set || !!upEvent.shiftKey;
      tableState.dragging = null;
      clearZoneHighlights();
      source.classList.remove("is-dragging");
      if (legal) {
        clone.remove();
        if (infoKind === "hand") {
          playCard(key, slot, set);
        } else {
          tableState.selected = { kind: "board", lane: lane, key: key };
          attack(Number(slot.dataset.lane));
        }
      } else {
        clone.style.transition = "left 0.16s ease, top 0.16s ease, opacity 0.16s ease";
        clone.style.left = originRect.left + "px";
        clone.style.top = originRect.top + "px";
        clone.style.opacity = "0";
        setTimeout(function () {
          clone.remove();
        }, 190);
        source.classList.add("is-invalid");
        setTimeout(function () {
          source.classList.remove("is-invalid");
        }, 220);
      }
      updateDockHint();
    }

    document.addEventListener("pointermove", onMove, { passive: false });
    document.addEventListener("pointerup", onUp);
    document.addEventListener("pointercancel", onUp);
  }

  function startDrag(sourceEl, info, originRect) {
    var imgKey = info.kind === "hand" ? info.key : info.key;
    if (!imgKey) return null;
    var clone = document.createElement("div");
    clone.className = "ux-dragclone";
    clone.style.left = originRect.left + "px";
    clone.style.top = originRect.top + "px";
    var cloneWidth = originRect.width;
    var cloneHeight = originRect.width * 1.4;
    clone.style.width = cloneWidth + "px";
    clone.style.height = cloneHeight + "px";
    clone.innerHTML = '<img src="' + CARD_IMAGES[imgKey] + '" alt="" />';
    document.body.appendChild(clone);
    sourceEl.classList.add("is-dragging");
    var table = $("#uxTable");
    if (table && table.dataset.panel === "overlay" && table.classList.contains("is-panel-open")) {
      table.classList.remove("is-panel-open");
      updatePanelButton();
    }
    tableState.dragging = {
      kind: info.kind,
      key: info.key,
      lane: info.lane,
      clone: clone,
      sourceEl: sourceEl,
      width: cloneWidth,
      height: cloneHeight,
      set: false
    };
    if (info.kind === "hand") highlightForHand(info.key);
    else highlightForBoard();
    updateDockHint();
    return tableState.dragging;
  }

  function slotAtPoint(x, y) {
    var node = document.elementFromPoint(x, y);
    return node ? node.closest(".ux-slot") : null;
  }

  function dropIsLegal(drag, slot) {
    if (!slot) return false;
    if (drag.kind === "hand") return isLegalHandDrop(drag.key, slot);
    return isLegalTarget(slot);
  }

  /* ================================================================== */
  /* picks                                                               */
  /* ================================================================== */

  var PICK_LABELS = {
    name: { N1: "Surface rename only", N2: "Full rename + aliases", N3: "Hard cut" },
    pack: { P0: "Keep the sealed envelope", P1: "Rip & Fan", P2: "Reliquary Case", P3: "Stack Peel" },
    panel: { R1: "Pinned cockpit rail", R2: "Edge Peek", R3: "Command Deck", R4: "Bottom drawer" },
    hand: { H0: "Spring Shelf 30%", H1: "Readable Tray 60%", H2: "Full Hand", H3: "Fan Arc", H4: "Side Hand" },
    drag: { D0: "Click-Select", D1: "Direct Drag", D2: "Magnetic Drop", D4: "Hybrid" }
  };

  function readPicks() {
    var form = $("#uxForm");
    if (!form) return null;
    var data = {
      name: (form.querySelector('input[name="ux-name"]:checked') || {}).value || "N2",
      pack: (form.querySelector('input[name="ux-pack"]:checked') || {}).value || "P1",
      panel: (form.querySelector('input[name="ux-panel"]:checked') || {}).value || "R2",
      hand: (form.querySelector('input[name="ux-hand"]:checked') || {}).value || "H1",
      drag: (form.querySelector('input[name="ux-drag"]:checked') || {}).value || "D4",
      extras: $$('input[name="ux-extra"]:checked').map(function (input) {
        return input.value;
      }),
      notes: ($("#uxNotes") || {}).value || ""
    };
    return data;
  }

  function pickSummary(data) {
    var lines = [
      "RAZEAH — PACKS + TABLE UX REVIEW",
      "",
      "Naming: " + data.name + " · " + (PICK_LABELS.name[data.name] || data.name),
      "Pack format: " + data.pack + " · " + (PICK_LABELS.pack[data.pack] || data.pack),
      "Panel @1440: " + data.panel + " · " + (PICK_LABELS.panel[data.panel] || data.panel),
      "Hand @1440: " + data.hand + " · " + (PICK_LABELS.hand[data.hand] || data.hand),
      "Drag: " + data.drag + " · " + (PICK_LABELS.drag[data.drag] || data.drag),
      "Also: " + (data.extras.length ? data.extras.join(" · ") : "none")
    ];
    if (data.notes.trim()) {
      lines.push("", "NOTES", data.notes.trim());
    }
    lines.push("", "Recommended package: Wave 0 naming → Wave 1 panel + hand → Wave 2 drag → Wave 3 pack ceremony.");
    return lines.join("\n");
  }

  function savePicks(silent) {
    var data = readPicks();
    if (!data) return;
    try {
      localStorage.setItem("razeah-ux-picks", JSON.stringify(data));
    } catch (err) {
      /* file:// private mode can reject storage; the review still works. */
    }
    var summary = $("#uxSummary");
    if (summary) summary.textContent = pickSummary(data);
    if (!silent) {
      var saved = $("#uxSaved");
      if (saved) {
        saved.classList.add("is-on");
        clearTimeout(saved._timer);
        saved._timer = setTimeout(function () {
          saved.classList.remove("is-on");
        }, 900);
      }
    }
  }

  function loadPicks() {
    var data = null;
    try {
      data = JSON.parse(localStorage.getItem("razeah-ux-picks") || "null");
    } catch (err) {
      data = null;
    }
    if (!data || typeof data !== "object") {
      savePicks(true);
      return;
    }
    [["ux-name", data.name], ["ux-pack", data.pack], ["ux-panel", data.panel], ["ux-hand", data.hand], ["ux-drag", data.drag]].forEach(function (pair) {
      var input = document.querySelector('input[name="' + pair[0] + '"][value="' + pair[1] + '"]');
      if (input) input.checked = true;
    });
    $$('input[name="ux-extra"]').forEach(function (input) {
      input.checked = Array.isArray(data.extras) && data.extras.indexOf(input.value) > -1;
    });
    var notes = $("#uxNotes");
    if (notes) notes.value = data.notes || "";
    savePicks(true);
  }

  function resetPicks() {
    var form = $("#uxForm");
    if (!form) return;
    form.reset();
    var notes = $("#uxNotes");
    if (notes) notes.value = "";
    savePicks();
    showToast("Shortlist reset to the panel recommendation.");
  }

  function copyPicks() {
    var data = readPicks();
    if (!data) return;
    var text = pickSummary(data);
    var done = function () {
      showToast("Feedback copied · paste it into the chat.");
    };
    var fallback = function () {
      window.prompt("Copy feedback", text);
    };
    if (navigator.clipboard && window.isSecureContext) {
      navigator.clipboard.writeText(text).then(done).catch(fallback);
    } else {
      try {
        var area = document.createElement("textarea");
        area.value = text;
        area.setAttribute("readonly", "");
        area.style.position = "fixed";
        area.style.left = "-9999px";
        document.body.appendChild(area);
        area.select();
        document.execCommand("copy");
        area.remove();
        done();
      } catch (err) {
        fallback();
      }
    }
  }

  /* ================================================================== */
  /* shell                                                               */
  /* ================================================================== */

  function updateProgress() {
    var bar = $("#uxProgress");
    if (!bar) return;
    var max = document.documentElement.scrollHeight - window.innerHeight;
    var progress = max > 0 ? Math.min(1, Math.max(0, window.scrollY / max)) : 0;
    bar.style.width = (progress * 100).toFixed(2) + "%";
  }

  function updateNav() {
    var y = window.scrollY + 140;
    var active = "";
    ["panel", "brief", "packs", "table-panel", "hand", "drag", "table-lab", "pick"].forEach(function (id) {
      var el = document.getElementById(id);
      if (el && el.getBoundingClientRect().top + window.scrollY <= y) active = id;
    });
    $$(".mastnav a").forEach(function (link) {
      var href = link.getAttribute("href") || "";
      link.classList.toggle("is-active", href === "#" + active);
    });
  }

  /* ================================================================== */
  /* boot                                                                */
  /* ================================================================== */

  function bindEvents() {
    $$("[data-packmode]").forEach(function (button) {
      button.addEventListener("click", function () {
        setPackMode(button.getAttribute("data-packmode"));
      });
    });

    document.addEventListener("click", function (event) {
      if (event.target.closest("[data-pack-reset]")) {
        resetPackLab();
        return;
      }
      if (event.target.closest("[data-hand-mode]")) {
        setHandMode(event.target.closest("[data-hand-mode]").getAttribute("data-hand-mode"));
        return;
      }
      if (event.target.closest("[data-panel-mode]")) {
        setPanelMode(event.target.closest("[data-panel-mode]").getAttribute("data-panel-mode"));
        return;
      }
      if (event.target.closest("[data-table-reset]")) {
        resetTable();
        return;
      }
      if (event.target.closest("#uxPanelButton")) {
        togglePanel();
        return;
      }
      if (event.target.closest("#uxPanelClose")) {
        closePanel();
        return;
      }
      if (event.target.closest("#uxPinButton")) {
        var table = $("#uxTable");
        setPanelMode(table.dataset.panel === "pinned" ? "overlay" : "pinned");
        return;
      }
      if (event.target.closest("#uxScrim")) {
        closePanel();
        return;
      }
      var tab = event.target.closest("[data-ptab]");
      if (tab) {
        tableState.panelTab = tab.getAttribute("data-ptab");
        renderPanel();
        return;
      }
      var action = event.target.closest("[data-panel-action]");
      if (action) {
        var kind = action.getAttribute("data-panel-action");
        if (kind === "end") {
          tableState.log.push({ text: "You end the phase." });
          renderPanel();
          showToast("Phase ended · the Warden answers.");
          return;
        }
        if (kind === "attack") {
          attack(Number(action.getAttribute("data-lane")));
          return;
        }
        var key = action.getAttribute("data-key");
        var lane = Number(action.getAttribute("data-lane"));
        var info = CARD_INFO[key];
        var zone = info.type === "monster" ? "monster" : "backrow";
        var slot = slotFromBoard(0, zone, lane);
        if (slot) playCard(key, slot, kind === "set");
        return;
      }
      if (event.target.closest("#uxCopy")) {
        copyPicks();
        return;
      }
      if (event.target.closest("#uxReset")) {
        resetPicks();
        return;
      }
    });

    var form = $("#uxForm");
    if (form) {
      form.addEventListener("change", function () {
        savePicks();
      });
      form.addEventListener("input", function (event) {
        if (event.target && event.target.id === "uxNotes") savePicks();
      });
    }

    window.addEventListener("resize", function () {
      fitPack();
      fitTable();
    });
    window.addEventListener("scroll", function () {
      updateProgress();
      updateNav();
    }, { passive: true });
  }

  function init() {
    resetTableState();
    renderPackObject();
    setPackMode("rip");
    resetPackLab();
    setHandMode("tray");
    setPanelMode("overlay");
    renderTable();
    loadPicks();
    bindEvents();
    fitPack();
    fitTable();
    updateProgress();
    updateNav();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();

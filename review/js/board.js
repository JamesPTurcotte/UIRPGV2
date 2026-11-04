/* One board renderer. Seven themes. No forked components.
 *
 * The board is intentionally the same skeleton everywhere: four-tab nav,
 * run strip, Warden, three lanes, rails, hand, dock. The theme data attribute
 * changes skin, motion flavor, and timbre; the DOM stays identical.
 */
(function () {
  "use strict";

  var D = window.RAZEAH;
  var I = window.RazeahIcons;

  /* ------------------------------------------------------------------ */
  /* utilities                                                           */
  /* ------------------------------------------------------------------ */

  function esc(value) {
    return String(value).replace(/[&<>"]/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c];
    });
  }

  function fmt(n) {
    return Number(n).toLocaleString("en-US");
  }

  function wait(ms) {
    return new Promise(function (resolve) {
      setTimeout(resolve, ms);
    });
  }

  function reduced() {
    return (
      document.body.classList.contains("rz-reduce") ||
      window.matchMedia("(prefers-reduced-motion: reduce)").matches
    );
  }

  function sfx(name, theme) {
    if (window.RazeahSound) window.RazeahSound.play(name, theme);
  }

  function card(key) {
    return D.cards[key];
  }

  function q(ctx, sel) {
    return ctx.root.querySelector(sel);
  }

  function qa(ctx, sel) {
    return Array.prototype.slice.call(ctx.root.querySelectorAll(sel));
  }

  function rectOf(ctx, node) {
    var base = ctx.root.getBoundingClientRect();
    var r = node.getBoundingClientRect();
    return {
      left: r.left - base.left,
      top: r.top - base.top,
      width: r.width,
      height: r.height,
      cx: r.left - base.left + r.width / 2,
      cy: r.top - base.top + r.height / 2
    };
  }

  function segmentBar(count, fill) {
    var out = "";
    for (var i = 0; i < count; i++) {
      out += '<i class="' + (i < fill ? "is-on" : "") + '"></i>';
    }
    return out;
  }

  function rulesHtml(text) {
    var match = String(text).match(/^([A-Z][A-Z ]+):\s*(.+)$/);
    if (match) {
      return "<b>" + esc(match[1]) + ":</b> " + esc(match[2]);
    }
    return esc(text);
  }

  function typeLabel(c) {
    return (c.type + " · " + c.subtype).toUpperCase();
  }

  /* ------------------------------------------------------------------ */
  /* markup                                                              */
  /* ------------------------------------------------------------------ */

  function navMarkup(state) {
    var tabs = D.nav
      .map(function (tab) {
        return (
          '<button class="rz-tab' +
          (tab.active ? " is-active" : "") +
          '" type="button" data-action="' +
          (tab.active ? "noop" : tab.id === "packs" ? "packs" : "stub") +
          '" data-label="' +
          tab.label +
          '"' +
          (tab.badge ? ' data-badge="1"' : "") +
          ">" +
          tab.label +
          (tab.badge ? '<i class="rz-tab__badge">2</i>' : "") +
          "</button>"
        );
      })
      .join("");

    return (
      '<header class="rz-nav">' +
      '<div class="rz-brand"><span class="rz-brand__mark">R</span><span class="rz-brand__word">RAZEAH<small>THE ARTLESS CARD GAME</small></span></div>' +
      '<nav class="rz-tabs" aria-label="Main navigation">' +
      tabs +
      "</nav>" +
      '<div class="rz-navtools">' +
      '<button class="rz-iconbtn" type="button" data-action="sound" data-sound-toggle aria-label="Toggle sound">' +
      I.svg("soundOff") +
      "</button>" +
      '<button class="rz-iconbtn" type="button" data-action="stub" data-label="Settings" aria-label="Settings">' +
      I.svg("gear") +
      "</button>" +
      "</div>" +
      "</header>"
    );
  }

  function runStripMarkup(state) {
    var phases = D.board.phases
      .map(function (phase, i) {
        var cls = i === state.phase ? "is-active" : i < state.phase ? "is-done" : "";
        return (
          '<li class="' + cls + '"><i></i><span>' + phase + "</span></li>"
        );
      })
      .join("");

    return (
      '<div class="rz-runstrip">' +
      '<div class="rz-runid">DEPTH <b>03</b><em>·</em>CIRCUIT <b>02</b><em>·</em><span class="rz-runid__floor">The Drowned Nave</span></div>' +
      '<ol class="rz-phases" data-ref="phases" aria-label="Turn phases">' +
      phases +
      "</ol>" +
      '<div class="rz-runstats">' +
      '<span class="rz-runstat">TURN <b data-ref="turn">07</b></span>' +
      '<span class="rz-runstat">MARKS <b data-ref="marks">620</b></span>' +
      '<button class="rz-auto' +
      (state.auto ? " is-on" : "") +
      '" type="button" data-action="auto" data-ref="autoBtn" aria-pressed="' +
      (state.auto ? "true" : "false") +
      '"><span class="rz-auto__dot"></span><span class="rz-auto__label">AUTO</span></button>' +
      "</div>" +
      "</div>"
    );
  }

  function wardenMarkup(state) {
    var fill = Math.round((state.wardenResolve / D.board.warden.maxResolve) * 20);
    return (
      '<section class="rz-warden" aria-label="Warden">' +
      '<div class="rz-wardenseal" aria-hidden="true">' +
      '<span class="rz-wardenseal__halo"></span>' +
      '<span class="rz-wardenseal__ring"></span>' +
      I.svg("warden", "rz-wardenseal__icon") +
      '<span class="rz-wardenseal__ticks"></span>' +
      "</div>" +
      '<div class="rz-wardenid">' +
      '<p class="rz-kicker">WARDEN · FLOOR 03</p>' +
      "<h2>" +
      D.board.warden.name +
      "</h2>" +
      '<p class="rz-wardenid__sub">Hold · no modifier · <em>The Drowned Nave</em></p>' +
      "</div>" +
      '<div class="rz-resolve">' +
      '<div class="rz-resolve__head"><span>RESOLVE</span><b data-ref="wardenResolve">' +
      fmt(state.wardenResolve) +
      '</b><em>/ 4,000</em></div>' +
      '<div class="rz-bar rz-bar--lg" data-ref="wardenBar" aria-hidden="true">' +
      segmentBar(20, fill) +
      "</div>" +
      '<div class="rz-resolve__foot">' +
      '<span class="rz-guards" data-ref="guardsChip" title="The face stays sealed while any enemy monster remains in a monster zone.">' +
      I.svg("shield") +
      ' <b data-ref="guardCount">' +
      state.guards +
      "</b> GUARDS · FACE SEALED</span>" +
      '<span class="rz-intentchip">NEXT · TIDECALL · LANE II</span>' +
      "</div>" +
      "</div>" +
      '<div class="rz-wardenhand">' +
      '<span class="rz-wardenhand__label">HAND <b>3</b></span>' +
      '<div class="rz-minihand" aria-hidden="true">' +
      backMarkup(true) +
      backMarkup(true) +
      backMarkup(true) +
      "</div>" +
      '<span class="rz-wardenhand__label">DECK <b>32</b></span>' +
      "</div>" +
      "</section>"
    );
  }

  function leftRailMarkup(state) {
    return (
      '<aside class="rz-rail rz-rail--left" aria-label="Your side">' +
      '<div class="rz-panel rz-playerresolve">' +
      '<p class="rz-label">YOUR RESOLVE</p>' +
      '<div class="rz-bignum">3,400</div>' +
      '<div class="rz-bar rz-bar--player" aria-hidden="true">' +
      segmentBar(10, 8) +
      "</div>" +
      '<p class="rz-tiny"><span class="rz-live-dot"></span> STEADY · 85%</p>' +
      "</div>" +
      '<div class="rz-panel rz-piles">' +
      '<div class="rz-pile"><span>DECK</span><b>28</b></div>' +
      '<div class="rz-pile"><span>REMAINS</span><b>2</b></div>' +
      '<div class="rz-pile"><span>VOID</span><b>0</b></div>' +
      "</div>" +
      '<div class="rz-railfoot"><span class="rz-kbd">F2</span> BOARD <span class="rz-kbd">F3</span> CARD</div>' +
      "</aside>"
    );
  }

  function intentMarkup() {
    return (
      '<div class="rz-panel rz-intent">' +
      '<p class="rz-label">THE WARDEN\'S INTENT</p>' +
      '<h3 data-ref="intentName">' +
      I.svg("tide") +
      "<span>TIDECALL</span></h3>" +
      '<div class="rz-lanemap" data-ref="laneMap" aria-label="Target lane">' +
      "<i></i><i class=\"is-lit\"></i><i></i>" +
      "</div>" +
      '<p class="rz-intentline" data-ref="intentLine"><b>Lane II</b><span>·</span><strong>1,800</strong></p>' +
      '<p class="rz-taunt">“The tide remembers every name you drop.”</p>' +
      "</div>"
    );
  }

  function logMarkup(state) {
    return (
      '<div class="rz-panel rz-log">' +
      '<div class="rz-log__head"><span>TABLE LOG</span><button type="button" data-action="stub" data-label="Log">EXPAND</button></div>' +
      '<ol class="rz-log__lines" data-ref="log" aria-live="polite">' +
      state.log
        .slice(-4)
        .map(function (entry) {
          return (
            '<li class="rz-log__line rz-log__line--' +
            entry.kind +
            '"><span>T' +
            entry.turn +
            "</span> " +
            esc(entry.text) +
            "</li>"
          );
        })
        .join("") +
      "</ol>" +
      "</div>"
    );
  }

  function coachMarkup() {
    return (
      '<div class="rz-panel rz-coach">' +
      '<span class="rz-coach__label">TRY IT</span>' +
      "<p>Call the glowing card. Strike Lane II. End the turn. Or hit <b>AUTO</b> and watch the whole turn play itself.</p>" +
      "</div>"
    );
  }

  function laneState(slot) {
    return slot ? "GUARDED" : "OPEN";
  }

  function laneMarkup(lane, index) {
    var out =
      '<section class="rz-lane" data-lane="' +
      (index + 1) +
      '" aria-label="Lane ' +
      lane.numeral +
      '">';
    out +=
      '<span class="rz-lane__state">' +
      laneState(lane.enemy) +
      '</span><span class="rz-lane__num">' +
      lane.numeral +
      "</span>";

    out +=
      '<div class="rz-slot rz-slot--back rz-slot--enemy" data-side="enemy" data-row="back">' +
      (lane.enemyBack ? backMarkup(true, true) : '<span class="rz-slot__ghost">·</span>') +
      "</div>";

    out +=
      '<div class="rz-slot rz-slot--front rz-slot--enemy" data-side="enemy" data-row="front">' +
      (lane.enemy ? cardMarkup(lane.enemy.card) : '<span class="rz-slot__open">OPEN</span>') +
      "</div>";

    out +=
      '<div class="rz-seam" aria-hidden="true"><i></i><span>' +
      lane.numeral +
      "</span><i></i></div>";

    out +=
      '<div class="rz-slot rz-slot--front rz-slot--player" data-side="player" data-row="front">' +
      (lane.player
        ? cardMarkup(lane.player.card, "is-yours")
        : '<div class="rz-empty rz-empty--call"><span>+</span><small>CALL</small></div>') +
      "</div>";

    out +=
      '<div class="rz-slot rz-slot--back rz-slot--player" data-side="player" data-row="back">' +
      (lane.playerBack ? backMarkup(true, true) : '<span class="rz-slot__ghost">·</span>') +
      "</div>";

    out += "</section>";
    return out;
  }

  function handMarkup(state) {
    var cards = state.hand
      .map(function (entry, i) {
        var c = card(entry.key);
        var playable = entry.playable ? " is-playable" : "";
        return (
          '<div class="rz-handcard' +
          playable +
          '" style="--i:' +
          i +
          '; --rot:' +
          (i - 2) * 2.4 +
          'deg" role="button" tabindex="0" data-action="' +
          (entry.playable ? "summon" : "stub") +
          '" data-label="' +
          esc(c.name) +
          '" data-card="' +
          entry.key +
          '" aria-label="' +
          (entry.playable ? "Call " : "Inspect ") +
          esc(c.name) +
          '">' +
          cardMarkup(entry.key) +
          (entry.playable ? '<span class="rz-handcard__flag">CLICK TO CALL</span>' : "") +
          "</div>"
        );
      })
      .join("");

    return (
      '<div class="rz-handbar">' +
      '<div class="rz-handzone">' +
      '<div class="rz-handmeta"><span>HAND <b data-ref="handCount">' +
      state.hand.length +
      "</b></span><span>CLICK TO CALL · DRAG TO A LANE</span></div>" +
      '<div class="rz-hand">' +
      cards +
      "</div>" +
      "</div>" +
      '<div class="rz-dock">' +
      '<button class="rz-btn rz-btn--strike" type="button" data-action="strike" data-ref="strikeBtn" title="Strike the Lane II guard. The face is sealed while enemy monsters remain.">' +
      "<span>STRIKE</span><small>LANE II · 2,600</small></button>" +
      '<button class="rz-btn rz-btn--end" type="button" data-action="end" data-ref="endBtn">' +
      "<span>END TURN</span><small>CLASH → DUSK</small></button>" +
      '<button class="rz-reset" type="button" data-action="reset">' +
      I.svg("reset") +
      " RESET TABLE</button>" +
      "</div>" +
      "</div>"
    );
  }

  function cardMarkup(key, extraClass) {
    var c = card(key);
    var stats =
      c.atk === null
        ? '<span class="rz-stat rz-stat--atk"><small>ATK</small><b>—</b></span><span class="rz-stat rz-stat--def"><small>DEF</small><b>—</b></span>'
        : '<span class="rz-stat rz-stat--atk"><small>ATK</small><b>' +
          fmt(c.atk) +
          '</b></span><span class="rz-stat rz-stat--def"><small>DEF</small><b>' +
          fmt(c.def) +
          "</b></span>";

    return (
      '<article class="rz-card rz-card--' +
      c.type +
      " rz-rarity-" +
      c.rarity +
      (extraClass ? " " + extraClass : "") +
      '" data-name="' +
      esc(c.name) +
      '" data-attribute="' +
      c.attribute +
      '" aria-label="' +
      esc(
        c.name +
          ". " +
          typeLabel(c) +
          ". " +
          (c.atk === null ? "" : fmt(c.atk) + " attack, " + fmt(c.def) + " defense. ") +
          c.rules
      ) +
      '">' +
      '<div class="rz-card__inner">' +
      '<header class="rz-card__name"><span>' +
      esc(c.name) +
      '</span><i class="rz-rarity" aria-hidden="true"></i></header>' +
      '<div class="rz-card__seal" aria-hidden="true">' +
      '<span class="rz-card__ring"></span>' +
      '<span class="rz-card__ring rz-card__ring--2"></span>' +
      I.attr(c.attribute) +
      '<span class="rz-card__mark">' +
      c.name.charAt(0) +
      "</span>" +
      "</div>" +
      '<div class="rz-card__type">' +
      I.attr(c.attribute) +
      "<span>" +
      esc(typeLabel(c)) +
      "</span></div>" +
      '<div class="rz-card__rules">' +
      rulesHtml(c.rules) +
      "</div>" +
      '<div class="rz-card__stats">' +
      stats +
      "</div>" +
      '<footer class="rz-card__foot"><span>C · CORE</span><span>OFFER ' +
      c.offer +
      "</span></footer>" +
      "</div>" +
      "</article>"
    );
  }

  function backMarkup(mini, set) {
    return (
      '<div class="rz-card rz-card--back' +
      (mini ? " rz-card--mini" : "") +
      '" role="img" aria-label="Set card">' +
      '<div class="rz-card__backinner">' +
      '<span class="rz-card__backring"></span>' +
      I.svg("spark", "rz-card__backicon") +
      (set ? '<span class="rz-card__set">SET</span>' : "") +
      "</div>" +
      "</div>"
    );
  }

  function motesMarkup() {
    var out = "";
    for (var i = 0; i < 14; i++) {
      out +=
        '<span style="--x:' +
        (4 + Math.random() * 92).toFixed(2) +
        "%; --d:" +
        (7 + Math.random() * 9).toFixed(2) +
        "s; --delay:" +
        (-Math.random() * 16).toFixed(2) +
        "s; --s:" +
        (0.15 + Math.random() * 0.35).toFixed(2) +
        'cqw"></span>';
    }
    return out;
  }

  function boardMarkup(state) {
    return (
      '<div class="rz-atmos" aria-hidden="true">' +
      motesMarkup() +
      "</div>" +
      '<div class="rz-frame" aria-hidden="true"></div>' +
      '<div class="rz-cinema rz-cinema--top" aria-hidden="true"></div>' +
      '<div class="rz-cinema rz-cinema--bottom" aria-hidden="true"></div>' +
      navMarkup(state) +
      runStripMarkup(state) +
      wardenMarkup(state) +
      '<div class="rz-mid">' +
      leftRailMarkup(state) +
      '<main class="rz-arena" aria-label="Battlefield">' +
      '<div class="rz-lanes">' +
      D.board.lanes.map(laneMarkup).join("") +
      "</div>" +
      "</main>" +
      '<aside class="rz-rail rz-rail--right" aria-label="Warden intent and log">' +
      intentMarkup() +
      logMarkup(state) +
      coachMarkup() +
      "</aside>" +
      "</div>" +
      handMarkup(state) +
      '<div class="rz-fx" aria-hidden="true"></div>' +
      '<div class="rz-caption" aria-live="polite"></div>' +
      '<div class="rz-toast" role="status" aria-live="polite"></div>' +
      '<div class="rz-scan" aria-hidden="true"></div>'
    );
  }

  /* ------------------------------------------------------------------ */
  /* render + state                                                      */
  /* ------------------------------------------------------------------ */

  function freshState() {
    return {
      phase: D.board.run.phase,
      turn: D.board.run.turn,
      marks: D.board.run.marks,
      wardenResolve: D.board.warden.resolve,
      guards: D.board.warden.guards,
      hand: D.board.hand.map(function (h) {
        return { key: h.card, playable: !!h.playable };
      }),
      log: D.board.log.map(function (entry) {
        return { kind: entry.kind, text: entry.text, turn: D.board.run.turn };
      }),
      summoned: false,
      struck: false,
      ended: false,
      auto: false
    };
  }

  function render(ctx) {
    ctx.root.innerHTML = boardMarkup(ctx.state);
    ctx.root.dataset.theme = ctx.theme;
    ctx.root.classList.toggle("is-auto", !!ctx.state.auto);
    if (window.RazeahSound) window.RazeahSound.sync();
  }

  function mount(container, themeId) {
    var root = document.createElement("div");
    root.className = "rz-board";
    root.dataset.theme = themeId;
    container.appendChild(root);

    var ctx = {
      root: root,
      theme: themeId,
      state: freshState(),
      autoToken: 0,
      captionTimer: null,
      toastTimer: null
    };

    root.addEventListener("click", function (event) {
      onClick(ctx, event);
    });
    root.addEventListener("keydown", function (event) {
      if (event.key !== "Enter" && event.key !== " " && event.key !== "Spacebar") return;
      var target = event.target.closest('[role="button"]');
      if (!target || !root.contains(target)) return;
      event.preventDefault();
      target.click();
    });

    render(ctx);
    return ctx;
  }

  function reset(ctx, keepAuto) {
    ctx.autoToken++;
    ctx.state = freshState();
    if (keepAuto) ctx.state.auto = true;
    render(ctx);
    if (!keepAuto) sfx("click", ctx.theme);
    clearCaption(ctx);
  }

  /* ------------------------------------------------------------------ */
  /* readable state + small feedback                                     */
  /* ------------------------------------------------------------------ */

  function setPhase(ctx, index) {
    ctx.state.phase = index;
    qa(ctx, ".rz-phases li").forEach(function (li, i) {
      li.classList.toggle("is-active", i === index);
      li.classList.toggle("is-done", i < index);
    });
  }

  function setTurn(ctx, turn) {
    ctx.state.turn = turn;
    var el = q(ctx, '[data-ref="turn"]');
    if (el) el.textContent = String(turn).padStart(2, "0");
  }

  function updateWardenResolve(ctx, next) {
    var old = ctx.state.wardenResolve;
    ctx.state.wardenResolve = Math.max(0, next);
    var bar = q(ctx, '[data-ref="wardenBar"]');
    var display = q(ctx, '[data-ref="wardenResolve"]');
    if (bar) {
      var fill = Math.round((ctx.state.wardenResolve / D.board.warden.maxResolve) * 20);
      Array.prototype.forEach.call(bar.children, function (seg, i) {
        seg.classList.toggle("is-on", i < fill);
      });
    }
    if (!display) return;
    if (reduced()) {
      display.textContent = fmt(ctx.state.wardenResolve);
      return;
    }
    var start = performance.now();
    var duration = 380;
    function tick(now) {
      var t = Math.min(1, (now - start) / duration);
      var eased = 1 - Math.pow(1 - t, 3);
      display.textContent = fmt(Math.round(old + (ctx.state.wardenResolve - old) * eased));
      if (t < 1) requestAnimationFrame(tick);
      else display.textContent = fmt(ctx.state.wardenResolve);
    }
    requestAnimationFrame(tick);
    display.classList.add("is-changing");
    setTimeout(function () {
      display.classList.remove("is-changing");
    }, 420);
  }

  function updateGuards(ctx, count) {
    ctx.state.guards = count;
    var n = q(ctx, '[data-ref="guardCount"]');
    var chip = q(ctx, '[data-ref="guardsChip"]');
    if (n) n.textContent = String(count);
    if (chip) {
      var label = count === 1 ? " GUARD · FACE SEALED" : " GUARDS · FACE SEALED";
      if (count === 0) label = " · FACE OPEN";
      chip.innerHTML = I.svg("shield") + " <b data-ref=\"guardCount\">" + count + "</b>" + label;
      chip.title =
        count === 0
          ? "All monster zones are clear. The face can be attacked."
          : "The face stays sealed while any enemy monster remains in a monster zone.";
    }
  }

  function pushLog(ctx, kind, text) {
    ctx.state.log.push({ kind: kind, text: text, turn: ctx.state.turn });
    var list = q(ctx, '[data-ref="log"]');
    if (!list) return;
    list.innerHTML = ctx.state.log
      .slice(-4)
      .map(function (entry) {
        return (
          '<li class="rz-log__line rz-log__line--' +
          entry.kind +
          '"><span>T' +
          entry.turn +
          "</span> " +
          esc(entry.text) +
          "</li>"
        );
      })
      .join("");
    var last = list.lastElementChild;
    if (last && !reduced()) {
      last.animate(
        [
          { opacity: 0, transform: "translateY(4px)" },
          { opacity: 1, transform: "translateY(0)" }
        ],
        { duration: 220, easing: "ease-out" }
      );
    }
  }

  function toast(ctx, text, kind) {
    var el = q(ctx, ".rz-toast");
    if (!el) return;
    el.className = "rz-toast is-show rz-toast--" + (kind || "system");
    el.textContent = text;
    clearTimeout(ctx.toastTimer);
    ctx.toastTimer = setTimeout(function () {
      el.classList.remove("is-show");
    }, 2400);
  }

  function clearCaption(ctx) {
    clearTimeout(ctx.captionTimer);
    var el = q(ctx, ".rz-caption");
    if (el) el.classList.remove("is-show");
  }

  function caption(ctx, index, duration) {
    var beat = D.autoBeats[index];
    if (!beat) return;
    var el = q(ctx, ".rz-caption");
    if (!el) return;
    el.innerHTML =
      '<span class="rz-caption__no">' +
      String(index + 1).padStart(2, "0") +
      '</span><span class="rz-caption__label">' +
      esc(beat.label) +
      "</span><strong>" +
      esc(beat.title) +
      "</strong><small>" +
      esc(beat.detail) +
      '</small><i class="rz-caption__progress" style="--dur:' +
      (duration || beat.ms) +
      'ms"></i>';
    el.classList.remove("is-show");
    void el.offsetWidth;
    el.classList.add("is-show");
    clearTimeout(ctx.captionTimer);
    ctx.captionTimer = setTimeout(function () {
      el.classList.remove("is-show");
    }, duration || beat.ms);
  }

  function focusLane(ctx, laneNo, hold) {
    qa(ctx, ".rz-lane").forEach(function (lane) {
      var n = Number(lane.dataset.lane);
      lane.classList.toggle("is-focus", n === laneNo);
      lane.classList.toggle("is-dim", laneNo > 0 && n !== laneNo);
    });
    clearTimeout(ctx.focusTimer);
    if (hold !== true) {
      ctx.focusTimer = setTimeout(function () {
        qa(ctx, ".rz-lane").forEach(function (lane) {
          lane.classList.remove("is-focus", "is-dim");
        });
      }, 1300);
    }
  }

  function clearFocus(ctx) {
    qa(ctx, ".rz-lane").forEach(function (lane) {
      lane.classList.remove("is-focus", "is-dim");
    });
  }

  function dockState(ctx) {
    var strike = q(ctx, '[data-ref="strikeBtn"]');
    var end = q(ctx, '[data-ref="endBtn"]');
    if (strike) {
      strike.classList.toggle("is-spent", ctx.state.struck);
      strike.innerHTML = ctx.state.struck
        ? "<span>LANE II BROKEN</span><small>2 GUARDS REMAIN</small>"
        : "<span>STRIKE</span><small>LANE II · 2,600</small>";
    }
    if (end) {
      end.classList.toggle("is-spent", ctx.state.ended);
      end.innerHTML = ctx.state.ended
        ? "<span>TURN PASSED</span><small>RESET TO REPLAY</small>"
        : "<span>END TURN</span><small>CLASH → DUSK</small>";
    }
  }

  /* ------------------------------------------------------------------ */
  /* effects                                                             */
  /* ------------------------------------------------------------------ */

  function fx(ctx) {
    return q(ctx, ".rz-fx");
  }

  function flash(ctx, target, kind) {
    var layer = fx(ctx);
    if (!layer) return;
    var r = rectOf(ctx, target);
    var size = Math.max(r.width, r.height) * 1.35;
    var el = document.createElement("span");
    el.className = "rz-flash rz-flash--" + (kind || "hit");
    el.style.left = r.cx - size / 2 + "px";
    el.style.top = r.cy - size / 2 + "px";
    el.style.width = size + "px";
    el.style.height = size + "px";
    layer.appendChild(el);
    if (reduced()) {
      setTimeout(function () {
        el.remove();
      }, 120);
      return;
    }
    el.animate(
      [
        { opacity: 0.95, transform: "scale(.35) rotate(0deg)" },
        { opacity: 0, transform: "scale(1.7) rotate(8deg)" }
      ],
      { duration: 320, easing: "cubic-bezier(.16,.84,.36,1)" }
    );
    setTimeout(function () {
      el.remove();
    }, 360);
  }

  function burst(ctx, target, count, kind) {
    var layer = fx(ctx);
    if (!layer) return;
    var r = rectOf(ctx, target);
    var total = reduced() ? 6 : count || 22;
    for (var i = 0; i < total; i++) {
      var p = document.createElement("span");
      p.className = "rz-particle rz-particle--" + (kind || "hit");
      var angle = Math.random() * Math.PI * 2;
      var dist = 20 + Math.random() * (r.width * 0.85);
      p.style.left = r.cx + "px";
      p.style.top = r.cy + "px";
      p.style.setProperty("--dx", Math.cos(angle) * dist + "px");
      p.style.setProperty("--dy", Math.sin(angle) * dist - 14 + "px");
      p.style.setProperty("--rot", Math.random() * 540 - 270 + "deg");
      p.style.setProperty("--size", 3 + Math.random() * 7 + "px");
      p.style.setProperty("--delay", Math.random() * 90 + "ms");
      layer.appendChild(p);
      var anim = p.animate(
        [
          { opacity: 1, transform: "translate(-50%,-50%) rotate(0deg) scale(1)" },
          {
            opacity: 0,
            transform:
              "translate(calc(-50% + var(--dx)), calc(-50% + var(--dy))) rotate(var(--rot)) scale(.15)"
          }
        ],
        {
          duration: 480 + Math.random() * 420,
          delay: Math.random() * 80,
          easing: "cubic-bezier(.12,.75,.28,1)",
          fill: "forwards"
        }
      );
      (function (node, animation) {
        animation.onfinish = function () {
          node.remove();
        };
        setTimeout(function () {
          if (node.parentNode) node.remove();
        }, 1200);
      })(p, anim);
    }
  }

  function floatNumber(ctx, target, text, kind, size) {
    var layer = fx(ctx);
    if (!layer) return;
    var r = rectOf(ctx, target);
    var el = document.createElement("div");
    el.className = "rz-dmg rz-dmg--" + (kind || "hit") + (size ? " rz-dmg--" + size : "");
    el.textContent = text;
    el.style.left = r.cx + "px";
    el.style.top = r.top + r.height * 0.26 + "px";
    layer.appendChild(el);
    if (reduced()) {
      setTimeout(function () {
        el.remove();
      }, 700);
      return;
    }
    el.animate(
      [
        { opacity: 0, transform: "translate(-50%,-30%) scale(.5) rotate(-6deg)", easing: "cubic-bezier(.2,.9,.24,1)" },
        { opacity: 1, transform: "translate(-50%,-50%) scale(1.2) rotate(2deg)", offset: 0.24, easing: "ease-out" },
        { opacity: 1, transform: "translate(-50%,-58%) scale(1) rotate(0deg)", offset: 0.62, easing: "ease-in" },
        { opacity: 0, transform: "translate(-50%,-105%) scale(.94) rotate(-2deg)" }
      ],
      { duration: 980, easing: "linear" }
    );
    setTimeout(function () {
      el.remove();
    }, 1040);
  }

  function scorePlate(ctx, kicker, value, detail) {
    var old = q(ctx, ".rz-scorecard");
    if (old) old.remove();
    var el = document.createElement("div");
    el.className = "rz-scorecard";
    el.innerHTML =
      '<span class="rz-scorecard__kicker">' +
      esc(kicker) +
      '</span><strong>' +
      esc(value) +
      '</strong><small>' +
      esc(detail) +
      "</small>";
    ctx.root.appendChild(el);
    if (reduced()) {
      setTimeout(function () {
        el.remove();
      }, 900);
      return;
    }
    el.animate(
      [
        { opacity: 0, transform: "translate(-50%,-50%) scale(.55) rotate(-5deg)", easing: "cubic-bezier(.18,.9,.22,1)" },
        { opacity: 1, transform: "translate(-50%,-50%) scale(1.12) rotate(1deg)", offset: 0.18, easing: "ease-out" },
        { opacity: 1, transform: "translate(-50%,-50%) scale(1) rotate(0deg)", offset: 0.62, easing: "ease-in" },
        { opacity: 0, transform: "translate(-50%,-62%) scale(1.02) rotate(1deg)" }
      ],
      { duration: 1350, easing: "linear" }
    );
    setTimeout(function () {
      el.remove();
    }, 1380);
  }

  function shake(ctx, amount) {
    if (reduced()) return;
    ctx.root.animate(
      [
        { transform: "translate(0,0)" },
        { transform: "translate(" + -amount + "px," + amount * 0.5 + "px)" },
        { transform: "translate(" + amount * 0.8 + "px," + -amount * 0.35 + "px)" },
        { transform: "translate(" + -amount * 0.45 + "px,0)" },
        { transform: "translate(0,0)" }
      ],
      { duration: 230, easing: "cubic-bezier(.2,.8,.3,1)" }
    );
  }

  function wave(ctx, laneNo) {
    var lane = q(ctx, '.rz-lane[data-lane="' + laneNo + '"]');
    if (!lane) return;
    var layer = fx(ctx);
    var r = rectOf(ctx, lane);
    var el = document.createElement("span");
    el.className = "rz-wave";
    el.style.left = r.cx + "px";
    el.style.top = r.top + "px";
    el.style.height = r.height + "px";
    layer.appendChild(el);
    if (reduced()) {
      setTimeout(function () {
        el.remove();
      }, 250);
      return;
    }
    el.animate(
      [
        { opacity: 0, transform: "translate(-50%,0) scaleY(.2)", easing: "ease-out" },
        { opacity: 0.9, transform: "translate(-50%,35%) scaleY(.8)", offset: 0.55, easing: "ease-in" },
        { opacity: 0, transform: "translate(-50%,80%) scaleY(1.15)" }
      ],
      { duration: 620, easing: "linear" }
    );
    setTimeout(function () {
      el.remove();
    }, 660);
  }

  function flyCard(ctx, fromNode, slot, key, done) {
    var layer = fx(ctx);
    var from = rectOf(ctx, fromNode);
    var to = rectOf(ctx, slot);

    /* Measure the card the slot will actually hold, not the slot itself. */
    var probe = document.createElement("div");
    probe.innerHTML = cardMarkup(key);
    var probeCard = probe.firstElementChild;
    probeCard.style.position = "absolute";
    probeCard.style.visibility = "hidden";
    probeCard.style.pointerEvents = "none";
    slot.appendChild(probeCard);
    var targetWidth = probeCard.getBoundingClientRect().width;
    probeCard.remove();

    var clone = document.createElement("div");
    clone.className = "rz-fly";
    clone.innerHTML = cardMarkup(key);
    clone.style.left = from.left + "px";
    clone.style.top = from.top + "px";
    clone.style.width = from.width + "px";
    var cloneCard = clone.querySelector(".rz-card");
    if (cloneCard) cloneCard.style.setProperty("--card-w", from.width + "px");
    layer.appendChild(clone);
    fromNode.classList.add("is-launching");

    if (reduced()) {
      clone.remove();
      done();
      return;
    }
    var scale = targetWidth / from.width;
    var dx = to.left + to.width / 2 - (from.left + from.width / 2);
    var dy = to.top + to.height / 2 - (from.top + from.height / 2);
    clone.animate(
      [
        { transform: "translate(0,0) scale(1) rotate(0deg)", opacity: 1, easing: "ease-in-out" },
        {
          transform: "translate(" + dx * 0.42 + "px," + (dy * 0.2 - 48) + "px) scale(1.3) rotate(-5deg)",
          offset: 0.48,
          easing: "ease-in"
        },
        {
          transform: "translate(" + dx + "px," + dy + "px) scale(" + scale + ") rotate(2deg)",
          opacity: 1,
          offset: 0.92,
          easing: "ease-out"
        },
        { transform: "translate(" + dx + "px," + dy + "px) scale(" + scale + ") rotate(0deg)", opacity: 0 }
      ],
      { duration: 620, easing: "linear" }
    );
    setTimeout(function () {
      clone.remove();
      done();
    }, 600);
  }

  /* ------------------------------------------------------------------ */
  /* actions                                                             */
  /* ------------------------------------------------------------------ */

  function summon(ctx, auto) {
    if (ctx.state.summoned) {
      if (!auto) toast(ctx, "Cinder Hound is already in the lane. Reset to replay.", "warn");
      return Promise.resolve();
    }
    ctx.state.summoned = true;
    var handCard = q(ctx, '.rz-handcard[data-card="cinderHound"]');
    var slot = q(ctx, '.rz-lane[data-lane="3"] [data-side="player"][data-row="front"]');
    if (!handCard || !slot) return Promise.resolve();

    focusLane(ctx, 3, auto);
    setPhase(ctx, 2);
    if (auto) caption(ctx, 1, 3400);
    sfx("summon", ctx.theme);
    burst(ctx, slot, 12, "summon");
    flash(ctx, slot, "summon");

    return new Promise(function (resolve) {
      flyCard(ctx, handCard, slot, "cinderHound", function () {
        slot.innerHTML = cardMarkup("cinderHound", "is-summoned is-yours");
        var landed = slot.querySelector(".rz-card");
        if (landed && !reduced()) {
          landed.animate(
            [
              { transform: "scale(1.16)", opacity: 0.2 },
              { transform: "scale(1)", opacity: 1 }
            ],
            { duration: 220, easing: "cubic-bezier(.2,.9,.3,1.2)" }
          );
        }
        burst(ctx, slot, 16, "summon");
        handCard.remove();
        var count = q(ctx, '[data-ref="handCount"]');
        if (count) count.textContent = String(ctx.state.hand.length - 1);
        var lane = q(ctx, '.rz-lane[data-lane="3"]');
        if (lane) {
          lane.classList.add("is-open");
          var stateEl = lane.querySelector(".rz-lane__state");
          if (stateEl) stateEl.textContent = "YOURS";
        }
        pushLog(ctx, "you", "You call Cinder Hound to Lane III.");
        if (!auto) toast(ctx, "CALLED · CINDER HOUND · LANE III", "good");

        setTimeout(function () {
          scorePlate(ctx, "KINDLE", "200", "THE DAMP WARDEN");
          var resolveEl = q(ctx, ".rz-resolve");
          if (resolveEl) {
            floatNumber(ctx, resolveEl, "−200", "kindle", "sm");
            flash(ctx, resolveEl, "gold");
          }
          updateWardenResolve(ctx, ctx.state.wardenResolve - 200);
          sfx("coin", ctx.theme);
          pushLog(ctx, "you", "KINDLE — the Warden takes 200.");
          if (auto) {
            clearTimeout(ctx.captionTimer);
            caption(ctx, 2, 2800);
          }
          setTimeout(function () {
            if (ctx.state.phase === 2) setPhase(ctx, 3);
            dockState(ctx);
            clearFocus(ctx);
            resolve();
          }, auto ? 1050 : 850);
        }, 380);
      });
    });
  }

  function strike(ctx, auto) {
    if (ctx.state.struck) {
      if (!auto) toast(ctx, "Lane II is already broken. End the turn.", "warn");
      return Promise.resolve();
    }
    ctx.state.struck = true;
    setPhase(ctx, 4);
    focusLane(ctx, 2, auto);
    if (auto) caption(ctx, 3, 3800);
    sfx("hit", ctx.theme);

    var attacker = q(ctx, '.rz-card[data-name="Verdant Colossus"]');
    var target = q(ctx, '.rz-card[data-name="Tidebound Archivist"]');
    var targetSlot = q(ctx, '.rz-lane[data-lane="2"] [data-side="enemy"][data-row="front"]');
    if (!attacker || !target) {
      if (!auto) toast(ctx, "The lane is already empty.", "warn");
      return Promise.resolve();
    }

    scorePlate(ctx, "STRIKE", "2,600", "VERDANT COLOSSUS → ARCHIVIST");
    if (!auto) toast(ctx, "STRIKE · LANE II · 2,600", "hit");

    return new Promise(function (resolve) {
      if (!reduced()) {
        attacker.animate(
          [
            { transform: "translateY(0) rotate(0deg) scale(1)", easing: "ease-in" },
            { transform: "translateY(-8px) rotate(-2deg) scale(1.02)", offset: 0.28, easing: "ease-in" },
            { transform: "translateY(-34px) rotate(3deg) scale(1.05)", offset: 0.66, easing: "ease-out" },
            { transform: "translateY(0) rotate(0deg) scale(1)" }
          ],
          { duration: 620, easing: "linear" }
        );
      }
      setTimeout(function () {
        /* impact frame */
        flash(ctx, target, "hit");
        burst(ctx, target, 30, "hit");
        burst(ctx, target, 10, "gold");
        shake(ctx, 7);
        floatNumber(ctx, target, "−2,600", "hit", "lg");
        sfx("destroy", ctx.theme);
        target.classList.add("is-hit");

        setTimeout(function () {
          if (!reduced()) {
            target.animate(
              [
                { transform: "translate(0,0) rotate(0deg) scale(1)", opacity: 1, easing: "ease-out" },
                { transform: "translate(5px,-6px) rotate(3deg) scale(1.02)", opacity: 1, offset: 0.2, easing: "ease-in" },
                { transform: "translate(0,22px) rotate(-8deg) scale(.72)", opacity: 0 }
              ],
              { duration: 430, easing: "linear", fill: "forwards" }
            );
          }
          setTimeout(function () {
            if (targetSlot) {
              targetSlot.innerHTML =
                '<div class="rz-empty rz-empty--broken"><span>BROKEN</span><small>LANE II OPEN</small></div>';
            }
            var lane = q(ctx, '.rz-lane[data-lane="2"]');
            if (lane) {
              lane.classList.add("is-open");
              var stateEl = lane.querySelector(".rz-lane__state");
              if (stateEl) stateEl.textContent = "OPEN";
              var map = q(ctx, '[data-ref="laneMap"]');
              if (map) map.children[1].classList.remove("is-lit");
            }
            updateGuards(ctx, ctx.state.guards - 1);
            pushLog(ctx, "you", "Verdant Colossus breaks Tidebound Archivist — 2,600.");
            pushLog(ctx, "system", "Lane II is open. 2 guards remain.");
            if (!auto) toast(ctx, "LANE II BROKEN · 2 GUARDS REMAIN", "good");
            dockState(ctx);
            setTimeout(function () {
              clearFocus(ctx);
              resolve();
            }, auto ? 780 : 420);
          }, 380);
        }, 90);
      }, reduced() ? 80 : 560);
    });
  }

  function endTurn(ctx, auto) {
    if (ctx.state.ended) {
      if (!auto) toast(ctx, "The Warden has already answered. Reset to replay.", "warn");
      return Promise.resolve();
    }
    ctx.state.ended = true;
    setPhase(ctx, 5);
    focusLane(ctx, 2, auto);
    if (auto) caption(ctx, 4, 3800);
    if (!auto) toast(ctx, "THE WARDEN CALLS THE TIDE", "warden");
    sfx("warden", ctx.theme);

    var seal = q(ctx, ".rz-wardenseal");
    if (seal) seal.classList.add("is-casting");
    wave(ctx, 2);

    var defender = q(ctx, '.rz-lane[data-lane="2"] [data-side="player"][data-row="front"] .rz-card');
    return new Promise(function (resolve) {
      setTimeout(function () {
        if (defender) {
          flash(ctx, defender, "warden");
          burst(ctx, defender, 24, "warden");
          floatNumber(ctx, defender, "−1,800", "warden", "lg");
          shake(ctx, 5);
          sfx("hit", ctx.theme);
          defender.classList.add("is-hit", "is-cracked");
          var def = defender.querySelector(".rz-stat--def b");
          if (def) def.textContent = "400";
          var stat = defender.querySelector(".rz-stat--def");
          if (stat) stat.classList.add("is-damaged");
        }
        pushLog(ctx, "warden", "TIDECALL — Verdant Colossus braces 1,800.");
        dockState(ctx);

        setTimeout(function () {
          if (seal) seal.classList.remove("is-casting");
          setTurn(ctx, ctx.state.turn + 1);
          setPhase(ctx, 0);
          var name = q(ctx, '[data-ref="intentName"]');
          if (name) name.innerHTML = I.svg("tide") + "<span>RIPTIDE</span>";
          var line = q(ctx, '[data-ref="intentLine"]');
          if (line) line.innerHTML = "<b>All lanes</b><span>·</span><strong>900</strong>";
          var map = q(ctx, '[data-ref="laneMap"]');
          if (map) {
            Array.prototype.forEach.call(map.children, function (dot) {
              dot.classList.add("is-lit");
            });
          }
          var chip = q(ctx, ".rz-intentchip");
          if (chip) chip.textContent = "NEXT · RIPTIDE · ALL LANES";
          pushLog(ctx, "system", "Turn 8 — Dawn. The Warden's intent shifts.");
          if (!auto) toast(ctx, "TURN 08 · DAWN · RIPTIDE INCOMING", "system");
          sfx("turn", ctx.theme);
          clearFocus(ctx);
          if (auto) {
            clearTimeout(ctx.captionTimer);
            caption(ctx, 5, 3200);
          }
          setTimeout(resolve, auto ? 1100 : 700);
        }, 1050);
      }, reduced() ? 100 : 620);
    });
  }

  /* ------------------------------------------------------------------ */
  /* auto mode                                                           */
  /* ------------------------------------------------------------------ */

  function setAutoButton(ctx, on) {
    var btn = q(ctx, '[data-ref="autoBtn"]');
    if (!btn) return;
    btn.classList.toggle("is-on", on);
    btn.setAttribute("aria-pressed", on ? "true" : "false");
    var label = btn.querySelector(".rz-auto__label");
    if (label) label.textContent = on ? "STOP" : "AUTO";
  }

  async function runAuto(ctx) {
    var token = ++ctx.autoToken;
    var live = function () {
      return ctx.state.auto && ctx.autoToken === token;
    };

    ctx.state.auto = true;
    ctx.root.classList.add("is-auto");
    setAutoButton(ctx, true);
    sfx("click", ctx.theme);

    await wait(reduced() ? 80 : 520);
    if (!live()) return;
    if (!reduced()) caption(ctx, 0, 1100);
    await wait(reduced() ? 120 : 1050);
    if (!live()) return;

    await summon(ctx, true);
    if (!live()) return;
    await wait(reduced() ? 120 : 420);
    if (!live()) return;

    await strike(ctx, true);
    if (!live()) return;
    await wait(reduced() ? 120 : 420);
    if (!live()) return;

    await endTurn(ctx, true);
    if (!live()) return;

    clearFocus(ctx);
    scorePlate(ctx, "TURN 08", "DAWN", "AUTO REPLAYS IN 3");
    if (!reduced()) {
      var cap = q(ctx, ".rz-caption");
      if (cap) {
        cap.innerHTML =
          '<span class="rz-caption__no">END</span><span class="rz-caption__label">AUTO</span><strong>SEQUENCE COMPLETE</strong><small>Replaying in 3…</small><i class="rz-caption__progress" style="--dur:2800ms"></i>';
        cap.classList.add("is-show");
      }
    }

    await wait(reduced() ? 500 : 2800);
    if (!live()) return;

    ctx.root.classList.add("is-resetting");
    await wait(reduced() ? 40 : 300);
    if (!live()) {
      ctx.root.classList.remove("is-resetting");
      return;
    }
    reset(ctx, true);
    ctx.root.classList.remove("is-resetting");
    await wait(reduced() ? 60 : 320);
    if (ctx.state.auto) runAuto(ctx);
  }

  function toggleAuto(ctx) {
    if (ctx.state.auto) {
      ctx.state.auto = false;
      ctx.autoToken++;
      ctx.root.classList.remove("is-auto");
      setAutoButton(ctx, false);
      clearFocus(ctx);
      clearCaption(ctx);
      qa(ctx, ".rz-lane").forEach(function (lane) {
        lane.classList.remove("is-focus", "is-dim");
      });
      toast(ctx, "AUTO STOPPED · TAKE THE TABLE", "system");
      return;
    }
    reset(ctx, true);
    ctx.state.auto = true;
    runAuto(ctx);
  }

  /* ------------------------------------------------------------------ */
  /* input                                                               */
  /* ------------------------------------------------------------------ */

  function onClick(ctx, event) {
    var target = event.target.closest("[data-action]");
    if (!target || !ctx.root.contains(target)) return;
    var action = target.dataset.action;
    if (!action || action === "noop") return;

    if (ctx.state.auto && action !== "auto" && action !== "reset" && action !== "sound") {
      toast(ctx, "AUTO is running. Press STOP to take over.", "warn");
      return;
    }

    if (action === "sound") {
      if (window.RazeahSound) window.RazeahSound.toggle();
      return;
    }

    if (action === "reset") {
      reset(ctx, false);
      return;
    }

    if (action === "auto") {
      toggleAuto(ctx);
      return;
    }

    if (action === "packs") {
      if (ctx.theme === "neon") {
        window.location.href = "packs.html";
      } else {
        toast(ctx, "PACKS · THE NEON PACK RITUAL IS THE BUILT ROOM", "system");
      }
      return;
    }

    if (action === "summon") {
      sfx("click", ctx.theme);
      summon(ctx, false);
      return;
    }

    if (action === "strike") {
      strike(ctx, false);
      return;
    }

    if (action === "end") {
      endTurn(ctx, false);
      return;
    }

    if (action === "stub") {
      var label = target.dataset.label || "That room";
      toast(ctx, label.toUpperCase() + " · NOT IN THIS REVIEW — THE TABLE IS THE SUBJECT", "system");
      sfx("click", ctx.theme);
    }
  }

  window.RazeahBoard = {
    mount: mount,
    reset: reset,
    cardMarkup: cardMarkup,
    backMarkup: backMarkup,
    startAuto: function (ctx) {
      if (!ctx.state.auto) toggleAuto(ctx);
    }
  };
})();

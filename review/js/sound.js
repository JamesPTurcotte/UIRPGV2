/* Tiny procedural SFX engine. No audio files, no dependencies.
 * It exists so the review can be judged with sound on: impact, tail, and
 * theme timbre matter as much as the visuals.
 */
(function () {
  "use strict";

  var ctx = null;
  var master = null;
  var enabled = false;
  var noiseBuffer = null;

  function ensure() {
    if (ctx) return ctx;
    var AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return null;
    ctx = new AC();
    master = ctx.createGain();
    master.gain.value = 0.18;
    master.connect(ctx.destination);
    var length = Math.floor(ctx.sampleRate * 0.5);
    noiseBuffer = ctx.createBuffer(1, length, ctx.sampleRate);
    var data = noiseBuffer.getChannelData(0);
    for (var i = 0; i < length; i++) data[i] = Math.random() * 2 - 1;
    return ctx;
  }

  function now() {
    return ctx ? ctx.currentTime : 0;
  }

  function tone(opts) {
    if (!ctx) return;
    var t0 = now() + (opts.delay || 0);
    var osc = ctx.createOscillator();
    var gain = ctx.createGain();
    osc.type = opts.type || "sine";
    osc.frequency.setValueAtTime(opts.freq, t0);
    if (opts.to) osc.frequency.exponentialRampToValueAtTime(Math.max(20, opts.to), t0 + opts.dur);
    gain.gain.setValueAtTime(0.0001, t0);
    gain.gain.exponentialRampToValueAtTime(opts.gain || 0.12, t0 + (opts.attack || 0.006));
    gain.gain.exponentialRampToValueAtTime(0.0001, t0 + opts.dur);
    osc.connect(gain);
    gain.connect(master);
    osc.start(t0);
    osc.stop(t0 + opts.dur + 0.03);
  }

  function noise(opts) {
    if (!ctx) return;
    var t0 = now() + (opts.delay || 0);
    var src = ctx.createBufferSource();
    src.buffer = noiseBuffer;
    var filter = ctx.createBiquadFilter();
    filter.type = opts.filter || "bandpass";
    filter.frequency.setValueAtTime(opts.freq || 1200, t0);
    if (opts.to) filter.frequency.exponentialRampToValueAtTime(Math.max(40, opts.to), t0 + opts.dur);
    filter.Q.value = opts.q || 0.8;
    var gain = ctx.createGain();
    gain.gain.setValueAtTime(0.0001, t0);
    gain.gain.exponentialRampToValueAtTime(opts.gain || 0.16, t0 + 0.004);
    gain.gain.exponentialRampToValueAtTime(0.0001, t0 + opts.dur);
    src.connect(filter);
    filter.connect(gain);
    gain.connect(master);
    src.start(t0);
    src.stop(t0 + opts.dur + 0.03);
  }

  var THEME_SOUND = {
    lantern: { hit: [523, 784, 1046], tail: 0.5, noise: 900 },
    ink: { hit: [220, 330], tail: 0.2, noise: 600 },
    neon: { hit: [880, 1320], tail: 0.18, noise: 2400 },
    hearth: { hit: [392, 523, 659], tail: 0.4, noise: 700 },
    omen: { hit: [196, 294, 392], tail: 0.8, noise: 500 },
    delve: { hit: [110, 165], tail: 0.32, noise: 320 },
    riso: { hit: [660, 990], tail: 0.14, noise: 3200 }
  };

  function play(name, themeId) {
    if (!enabled) return;
    if (!ensure()) return;
    var cfg = THEME_SOUND[themeId] || THEME_SOUND.lantern;
    if (ctx.state === "suspended") ctx.resume();

    if (name === "click") {
      tone({ freq: 660, dur: 0.05, type: "sine", gain: 0.04 });
      return;
    }

    if (name === "hover") {
      tone({ freq: 1200, dur: 0.035, type: "sine", gain: 0.015 });
      return;
    }

    if (name === "summon") {
      noise({ dur: 0.28, gain: 0.06, freq: 300, to: 2200, filter: "bandpass", q: 1.2 });
      cfg.hit.forEach(function (f, i) {
        tone({ freq: f * 0.5, to: f, dur: 0.28, type: "triangle", gain: 0.05, delay: i * 0.045 });
      });
      return;
    }

    if (name === "hit") {
      noise({ dur: 0.18, gain: 0.15, freq: cfg.noise * 2, to: cfg.noise * 0.5, filter: "lowpass" });
      tone({ freq: 130, to: 46, dur: 0.24, type: "sine", gain: 0.22 });
      cfg.hit.forEach(function (f, i) {
        tone({ freq: f, dur: 0.12 + cfg.tail * 0.3, type: "triangle", gain: 0.045 - i * 0.008, delay: 0.01 + i * 0.012 });
      });
      return;
    }

    if (name === "destroy") {
      noise({ dur: 0.4, gain: 0.18, freq: cfg.noise, to: 120, filter: "lowpass", q: 0.6 });
      tone({ freq: 90, to: 32, dur: 0.45, type: "sawtooth", gain: 0.11 });
      return;
    }

    if (name === "warden") {
      noise({ dur: 0.6, gain: 0.1, freq: 200, to: 900, filter: "bandpass", q: 0.5 });
      tone({ freq: cfg.hit[0] * 0.5, to: cfg.hit[0] * 0.35, dur: 0.9, type: "sine", gain: 0.16 });
      tone({ freq: cfg.hit[0], dur: 0.7, type: "sine", gain: 0.04, delay: 0.06 });
      return;
    }

    if (name === "turn") {
      cfg.hit.forEach(function (f, i) {
        tone({ freq: f * 2, dur: 0.22, type: "sine", gain: 0.035, delay: i * 0.1 });
      });
      return;
    }

    if (name === "coin") {
      tone({ freq: 1320, dur: 0.09, type: "square", gain: 0.03 });
      tone({ freq: 1760, dur: 0.12, type: "square", gain: 0.025, delay: 0.06 });
      return;
    }

    /* ------------------------------------------------------------------
     * Folio ceremony cues. Same synth, same bus, no audio files.
     * ------------------------------------------------------------------ */

    if (name === "folioPress") {
      tone({ freq: 180, to: 130, dur: 0.08, type: "triangle", gain: 0.05 });
      noise({ dur: 0.06, gain: 0.035, freq: 800, to: 350, filter: "lowpass" });
      return;
    }

    if (name === "folioCrack") {
      noise({ dur: 0.16, gain: 0.18, freq: 1800, to: 180, filter: "bandpass", q: 0.7 });
      tone({ freq: 120, to: 48, dur: 0.2, type: "sine", gain: 0.2 });
      tone({ freq: 1480, dur: 0.06, type: "square", gain: 0.025, delay: 0.012 });
      return;
    }

    if (name === "folioFlap") {
      noise({ dur: 0.26, gain: 0.07, freq: 500, to: 1800, filter: "bandpass", q: 0.45 });
      return;
    }

    if (name === "folioDeal") {
      var level = 520 + Math.random() * 360;
      noise({ dur: 0.1, gain: 0.045, freq: level, to: level * 1.6, filter: "bandpass", q: 1.1 });
      tone({ freq: level * 0.5, dur: 0.09, type: "triangle", gain: 0.018 });
      return;
    }

    if (name === "folioTellCommon") {
      tone({ freq: 940, dur: 0.09, type: "sine", gain: 0.02 });
      return;
    }

    if (name === "folioTellUncommon") {
      tone({ freq: 880, dur: 0.12, type: "triangle", gain: 0.022 });
      tone({ freq: 1180, dur: 0.14, type: "triangle", gain: 0.018, delay: 0.06 });
      return;
    }

    if (name === "folioTellRare") {
      tone({ freq: 1046, dur: 0.28, type: "sine", gain: 0.026 });
      tone({ freq: 1568, dur: 0.22, type: "sine", gain: 0.016, delay: 0.04 });
      tone({ freq: 2093, dur: 0.18, type: "sine", gain: 0.009, delay: 0.09 });
      return;
    }

    if (name === "folioTellLegendary") {
      tone({ freq: 146, to: 110, dur: 0.7, type: "sine", gain: 0.1 });
      tone({ freq: 523, dur: 0.6, type: "sine", gain: 0.025 });
      tone({ freq: 784, dur: 0.5, type: "sine", gain: 0.018, delay: 0.08 });
      tone({ freq: 1046, dur: 0.4, type: "sine", gain: 0.012, delay: 0.16 });
      return;
    }

    if (name === "folioFlip") {
      noise({ dur: 0.11, gain: 0.09, freq: 1600, to: 380, filter: "bandpass", q: 0.7 });
      tone({ freq: 260, to: 170, dur: 0.08, type: "triangle", gain: 0.035 });
      return;
    }

    if (name === "folioRare") {
      tone({ freq: 1046, dur: 0.5, type: "sine", gain: 0.035 });
      tone({ freq: 1318, dur: 0.42, type: "sine", gain: 0.025, delay: 0.06 });
      tone({ freq: 2093, dur: 0.3, type: "sine", gain: 0.012, delay: 0.12 });
      return;
    }

    if (name === "folioLegendary") {
      tone({ freq: 98, to: 78, dur: 1.2, type: "sine", gain: 0.16 });
      tone({ freq: 196, dur: 1.1, type: "sine", gain: 0.06, delay: 0.02 });
      tone({ freq: 392, dur: 0.9, type: "sine", gain: 0.03, delay: 0.08 });
      tone({ freq: 784, dur: 0.7, type: "sine", gain: 0.018, delay: 0.18 });
      noise({ dur: 0.5, gain: 0.035, freq: 240, to: 1400, filter: "bandpass", q: 0.5 });
      return;
    }

    if (name === "folioStamp") {
      noise({ dur: 0.09, gain: 0.11, freq: 420, to: 180, filter: "lowpass" });
      tone({ freq: 146, to: 92, dur: 0.14, type: "triangle", gain: 0.09 });
      return;
    }

    if (name === "folioSummary") {
      [523, 659, 784].forEach(function (f, i) {
        tone({ freq: f, dur: 0.5, type: "sine", gain: 0.025, delay: i * 0.09 });
      });
      return;
    }

    if (name === "folioSkip") {
      noise({ dur: 0.22, gain: 0.06, freq: 2400, to: 300, filter: "bandpass", q: 0.6 });
      return;
    }

    if (name === "error") {
      tone({ freq: 150, to: 110, dur: 0.16, type: "square", gain: 0.04 });
    }
  }

  function syncButtons() {
    document.querySelectorAll("[data-sound-toggle]").forEach(function (btn) {
      btn.setAttribute("aria-pressed", enabled ? "true" : "false");
      btn.setAttribute("title", enabled ? "Sound on" : "Sound off");
      btn.innerHTML = window.RazeahIcons.svg(enabled ? "soundOn" : "soundOff");
    });
  }

  window.RazeahSound = {
    play: play,
    isEnabled: function () {
      return enabled;
    },
    setEnabled: function (value) {
      enabled = !!value;
      if (enabled) {
        ensure();
        if (ctx && ctx.state === "suspended") ctx.resume();
      }
      syncButtons();
    },
    toggle: function () {
      enabled = !enabled;
      if (enabled) {
        ensure();
        if (ctx && ctx.state === "suspended") ctx.resume();
        play("click", "lantern");
      }
      syncButtons();
      return enabled;
    },
    sync: syncButtons
  };
})();

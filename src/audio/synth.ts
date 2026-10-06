type Mood = 'hideout' | 'ash' | 'gild' | 'spire'

let ctx: AudioContext | null = null
let master: GainNode | null = null
let drone: OscillatorNode | null = null
let droneGain: GainNode | null = null
let lastHit = 0
let lastHurt = 0

function context(): AudioContext | null {
  if (typeof window === 'undefined') return null
  const Ctor = window.AudioContext ?? (window as Window & { webkitAudioContext?: typeof AudioContext }).webkitAudioContext
  if (!Ctor) return null
  if (!ctx) {
    ctx = new Ctor()
    master = ctx.createGain()
    master.gain.value = 0.85
    master.connect(ctx.destination)
  }
  return ctx
}

function tone(
  freq: number,
  dur: number,
  gain: number,
  type: OscillatorType = 'sine',
  slide = 0,
  when = 0,
) {
  const audio = context()
  if (!audio || !master) return
  const t = audio.currentTime + when
  const osc = audio.createOscillator()
  const amp = audio.createGain()
  osc.type = type
  osc.frequency.setValueAtTime(freq, t)
  if (slide) osc.frequency.linearRampToValueAtTime(Math.max(40, freq + slide), t + dur)
  amp.gain.setValueAtTime(gain, t)
  amp.gain.exponentialRampToValueAtTime(0.0001, t + dur)
  osc.connect(amp)
  amp.connect(master)
  osc.start(t)
  osc.stop(t + dur + 0.02)
}

function noise(dur: number, gain: number, freq = 800) {
  const audio = context()
  if (!audio || !master) return
  const t = audio.currentTime
  const length = Math.max(1, Math.floor(audio.sampleRate * dur))
  const buffer = audio.createBuffer(1, length, audio.sampleRate)
  const data = buffer.getChannelData(0)
  for (let i = 0; i < data.length; i++) data[i] = Math.random() * 2 - 1
  const src = audio.createBufferSource()
  src.buffer = buffer
  const filter = audio.createBiquadFilter()
  filter.type = 'bandpass'
  filter.frequency.value = freq
  const amp = audio.createGain()
  amp.gain.setValueAtTime(gain, t)
  amp.gain.exponentialRampToValueAtTime(0.0001, t + dur)
  src.connect(filter)
  filter.connect(amp)
  amp.connect(master)
  src.start(t)
  src.stop(t + dur)
}

function startDrone() {
  const audio = context()
  if (!audio || !master || drone) return
  drone = audio.createOscillator()
  drone.type = 'sine'
  drone.frequency.value = 52
  const filter = audio.createBiquadFilter()
  filter.type = 'lowpass'
  filter.frequency.value = 160
  droneGain = audio.createGain()
  droneGain.gain.value = 0.018
  drone.connect(filter)
  filter.connect(droneGain)
  droneGain.connect(master)
  drone.start()
}

export const audio = {
  unlock() {
    const audioCtx = context()
    if (!audioCtx) return
    if (audioCtx.state === 'suspended') void audioCtx.resume()
    startDrone()
  },
  setMood(mood: Mood) {
    const audioCtx = context()
    if (!audioCtx || !drone) return
    const freq = { hideout: 52, ash: 58, gild: 64, spire: 47 }[mood]
    drone.frequency.linearRampToValueAtTime(freq, audioCtx.currentTime + 0.45)
  },
  ui() {
    tone(740, 0.05, 0.03)
  },
  open() {
    tone(280, 0.12, 0.03, 'sine', 220)
  },
  hit() {
    const now = performance.now?.() ?? 0
    if (now - lastHit < 70) return
    lastHit = now
    tone(186, 0.06, 0.04, 'square')
  },
  hurt() {
    const now = performance.now?.() ?? 0
    if (now - lastHurt < 90) return
    lastHurt = now
    tone(110, 0.14, 0.05, 'sawtooth', -40)
  },
  drop(rarity: 'normal' | 'magic' | 'rare' | 'currency') {
    if (rarity === 'rare') {
      tone(523, 0.12, 0.04, 'triangle')
      tone(659, 0.14, 0.04, 'triangle', 0, 0.08)
      tone(784, 0.2, 0.045, 'triangle', 0, 0.16)
      return
    }
    if (rarity === 'magic') {
      tone(494, 0.1, 0.035, 'sine')
      tone(622, 0.14, 0.03, 'sine', 0, 0.07)
      return
    }
    if (rarity === 'currency') {
      tone(880, 0.08, 0.03, 'sine', 120)
      return
    }
    tone(420, 0.06, 0.025)
  },
  level() {
    tone(392, 0.12, 0.04, 'triangle')
    tone(523, 0.14, 0.04, 'triangle', 0, 0.09)
    tone(659, 0.22, 0.045, 'triangle', 0, 0.18)
  },
  death() {
    tone(220, 0.4, 0.05, 'sawtooth', -140)
  },
  clear() {
    tone(440, 0.12, 0.035, 'sine')
    tone(554, 0.14, 0.035, 'sine', 0, 0.1)
    tone(659, 0.22, 0.04, 'sine', 0, 0.2)
  },
  nova() {
    noise(0.18, 0.05, 420)
    tone(196, 0.2, 0.04, 'sine', 80)
  },
  craft() {
    tone(520, 0.08, 0.03, 'triangle')
    tone(700, 0.12, 0.03, 'triangle', 0, 0.06)
  },
}

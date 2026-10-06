export type Rng = () => number

export function rand(box: { rngState: number }): number {
  box.rngState = (box.rngState + 0x6d2b79f5) | 0
  let t = Math.imul(box.rngState ^ (box.rngState >>> 15), 1 | box.rngState)
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296
}

export function mulberry32(seed: number): Rng {
  const box = { rngState: seed | 0 }
  return () => rand(box)
}

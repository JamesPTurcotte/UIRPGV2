import type { DamageEvent, StatKey } from './types'
import type { Rng } from './rng'

export const NOVA_CD = 4.2
export const PLAYER_SPEED = 180
export const PLAYER_RADIUS = 14
export const PLAYER_RANGE = 62
export const PICKUP_RADIUS = 30
export const INVENTORY_SLOTS = 24
export const REGEN = 5

export function xpToNext(level: number): number {
  return 36 + level * 18
}

export function strike(
  damage: number,
  critChance: number,
  critMultiplier: number,
  rng: Rng,
): { amount: number; crit: boolean } {
  const crit = rng() < critChance
  const variance = 0.9 + rng() * 0.2
  const amount = Math.max(1, Math.round(damage * variance * (crit ? critMultiplier : 1)))
  return { amount, crit }
}

export function mitigate(raw: number, fireRes: number, hitsMod: number): number {
  const res = Math.min(75, Math.max(0, fireRes))
  const taken = raw * (1 - res / 100) * hitsMod
  return Math.max(1, Math.round(taken))
}

export function dpsBuckets(
  events: readonly DamageEvent[],
  now: number,
  seconds = 10,
  buckets = 20,
): number[] {
  const start = now - seconds
  const size = seconds / buckets
  const out = Array.from({ length: buckets }, () => 0)
  for (const event of events) {
    if (event.t < start || event.t > now) continue
    const index = Math.min(buckets - 1, Math.max(0, Math.floor((event.t - start) / size)))
    out[index] += event.amount
  }
  return out.map((value) => value / size)
}

export function rollingDps(events: readonly DamageEvent[], now: number, window = 4): number {
  const start = now - window
  let sum = 0
  for (const event of events) {
    if (event.t >= start && event.t <= now) sum += event.amount
  }
  return sum / window
}

export function formatDelta(stat: StatKey, delta: number): string {
  const sign = delta > 0 ? '+' : ''
  if (stat === 'attackSpeed') return `${sign}${delta.toFixed(2)}/s`
  if (stat === 'crit') return `${sign}${Math.round(delta * 100)}%`
  if (stat === 'fireRes') return `${sign}${Math.round(delta)}%`
  return `${sign}${Math.round(delta)}`
}

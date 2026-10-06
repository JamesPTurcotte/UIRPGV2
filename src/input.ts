export const held = new Set<string>()
const impulses = new Map<string, number>()

export function nudgeKey(key: string) {
  impulses.set(key, Math.max(impulses.get(key) ?? 0, 0.35))
}

export function movementHeld(dt: number): Set<string> {
  const keys = new Set(held)
  for (const [key, time] of impulses) {
    keys.add(key)
    const next = time - dt
    if (next <= 0) impulses.delete(key)
    else impulses.set(key, next)
  }
  return keys
}

const MOVE = new Set([
  'w',
  'a',
  's',
  'd',
  'arrowup',
  'arrowdown',
  'arrowleft',
  'arrowright',
])

export function isMoveKey(key: string): boolean {
  return MOVE.has(key)
}

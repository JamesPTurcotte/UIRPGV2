export const held = new Set<string>()

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

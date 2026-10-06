import type { StatKey } from './types'

export interface Passive {
  id: string
  name: string
  x: number
  y: number
  requires: string | null
  stat: StatKey
  value: number
  text: string
}

export const PASSIVES: Passive[] = [
  { id: 'n1', name: 'Ash Strike', x: 50, y: 16, requires: null, stat: 'damage', value: 4, text: '+4 damage' },
  { id: 'n2', name: 'Quick Ember', x: 26, y: 30, requires: 'n1', stat: 'attackSpeed', value: 0.08, text: '+8% attack speed' },
  { id: 'n3', name: 'Cinder Eye', x: 16, y: 48, requires: 'n2', stat: 'crit', value: 0.04, text: '+4% crit' },
  { id: 'n4', name: 'Heart of Coal', x: 74, y: 30, requires: null, stat: 'life', value: 18, text: '+18 life' },
  { id: 'n5', name: 'Deep Vein', x: 84, y: 48, requires: 'n4', stat: 'life', value: 22, text: '+22 life' },
  { id: 'n6', name: 'Kiln Skin', x: 78, y: 66, requires: 'n5', stat: 'fireRes', value: 12, text: '+12 fire res' },
  { id: 'n7', name: 'Splinter', x: 32, y: 66, requires: null, stat: 'damage', value: 5, text: '+5 damage' },
  { id: 'n8', name: 'Lucky Spark', x: 20, y: 82, requires: 'n7', stat: 'crit', value: 0.05, text: '+5% crit' },
  { id: 'n9', name: 'Measured Swing', x: 68, y: 82, requires: null, stat: 'attackSpeed', value: 0.1, text: '+10% attack speed' },
  { id: 'n10', name: 'Warm Gold', x: 50, y: 90, requires: 'n9', stat: 'fireRes', value: 10, text: '+10 fire res' },
  { id: 'n11', name: 'Last Coal', x: 50, y: 40, requires: null, stat: 'life', value: 14, text: '+14 life' },
  { id: 'n12', name: 'Brand', x: 50, y: 58, requires: 'n11', stat: 'damage', value: 6, text: '+6 damage' },
]

export function passiveById(id: string): Passive | undefined {
  return PASSIVES.find((node) => node.id === id)
}

export function canAllocate(
  id: string,
  allocated: readonly string[],
  points: number,
): boolean {
  if (points <= 0 || allocated.includes(id)) return false
  const node = passiveById(id)
  if (!node) return false
  if (node.requires && !allocated.includes(node.requires)) return false
  return true
}

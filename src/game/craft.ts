import type { Item } from './types'
import type { Rng } from './rng'
import { rollItem } from './items'

export function canReroll(item: Item | undefined): boolean {
  return item?.rarity === 'rare'
}

export function canUpgrade(item: Item | undefined): boolean {
  return item?.rarity === 'normal'
}

export function rerollRare(item: Item, rng: Rng): Item {
  const next = rollItem({
    rng,
    id: item.id,
    rarity: 'rare',
    slot: item.slot,
    baseId: item.baseId,
  })
  next.id = item.id
  return next
}

export function upgradeNormal(item: Item, rng: Rng): Item {
  const next = rollItem({
    rng,
    id: item.id,
    rarity: 'magic',
    slot: item.slot,
    baseId: item.baseId,
  })
  next.id = item.id
  return next
}

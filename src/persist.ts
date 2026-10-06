import type { GameState, Item, Slot } from './game/types'
import { BASES } from './game/items'
import { PASSIVES } from './game/passives'
import { MAPS } from './game/atlas'

const KEY = 'uirpg-save-v1'

export interface SaveData {
  v: 1
  auto: boolean
  level: number
  xp: number
  passivePoints: number
  allocated: string[]
  rerollOrbs: number
  upgradeOrbs: number
  inventory: Item[]
  equipped: Partial<Record<Slot, Item>>
  life: number
  cleared: Record<string, boolean>
  uid: number
  rngState: number
}

const SLOTS: Slot[] = ['weapon', 'armor', 'ring']
const RARITIES = new Set(['normal', 'magic', 'rare'])
const STATS = new Set(['damage', 'attackSpeed', 'crit', 'life', 'fireRes'])

function isItem(value: unknown): value is Item {
  if (!value || typeof value !== 'object') return false
  const item = value as Item
  if (typeof item.id !== 'string' || typeof item.name !== 'string') return false
  if (!SLOTS.includes(item.slot) || !RARITIES.has(item.rarity)) return false
  if (!BASES.some((base) => base.id === item.baseId)) return false
  if (!Array.isArray(item.affixes)) return false
  return item.affixes.every(
    (affix) =>
      affix &&
      typeof affix.id === 'string' &&
      typeof affix.name === 'string' &&
      STATS.has(affix.stat) &&
      typeof affix.value === 'number',
  )
}

export function toSave(g: GameState): SaveData {
  return {
    v: 1,
    auto: g.auto,
    level: g.level,
    xp: g.xp,
    passivePoints: g.passivePoints,
    allocated: [...g.allocated],
    rerollOrbs: g.rerollOrbs,
    upgradeOrbs: g.upgradeOrbs,
    inventory: g.inventory.map((item) => structuredClone(item)),
    equipped: structuredClone(g.equipped),
    life: g.life,
    cleared: { ...g.cleared },
    uid: g.uid,
    rngState: g.rngState,
  }
}

export function applySave(g: GameState, data: SaveData | null): void {
  if (!data || data.v !== 1) return
  const known = new Set(PASSIVES.map((node) => node.id))
  const maps = new Set(MAPS.map((map) => map.id))
  g.auto = data.auto !== false
  g.level = Math.max(1, Math.floor(Number(data.level) || 1))
  g.xp = Math.max(0, Number(data.xp) || 0)
  g.passivePoints = Math.max(0, Math.floor(Number(data.passivePoints) || 0))
  g.allocated = Array.isArray(data.allocated)
    ? data.allocated.filter((id) => known.has(id))
    : []
  g.rerollOrbs = Math.max(0, Math.floor(Number(data.rerollOrbs) || 0))
  g.upgradeOrbs = Math.max(0, Math.floor(Number(data.upgradeOrbs) || 0))
  g.inventory = Array.isArray(data.inventory) ? data.inventory.filter(isItem).slice(0, 24) : []
  g.equipped = {}
  if (data.equipped && typeof data.equipped === 'object') {
    for (const slot of SLOTS) {
      const item = data.equipped[slot]
      if (isItem(item) && item.slot === slot) g.equipped[slot] = item
    }
  }
  g.life = Math.max(1, Number(data.life) || g.life)
  g.cleared = {}
  if (data.cleared && typeof data.cleared === 'object') {
    for (const id of Object.keys(data.cleared)) {
      if (maps.has(id) && data.cleared[id]) g.cleared[id] = true
    }
  }
  g.uid = Math.max(10, Math.floor(Number(data.uid) || 10))
  g.rngState = Number.isFinite(data.rngState) ? data.rngState : g.rngState
  g.phase = 'title'
}

export function readSave(): SaveData | null {
  if (typeof localStorage === 'undefined') return null
  try {
    const raw = localStorage.getItem(KEY)
    if (!raw) return null
    const data = JSON.parse(raw) as SaveData
    if (!data || data.v !== 1) return null
    return data
  } catch {
    return null
  }
}

export function writeSave(g: GameState): void {
  if (typeof localStorage === 'undefined') return
  try {
    localStorage.setItem(KEY, JSON.stringify(toSave(g)))
  } catch {
    // A full quota should not stop the fight.
  }
}

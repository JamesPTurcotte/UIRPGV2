import type { Affix, Derived, Hero, Item, Rarity, Slot, StatKey } from './types'
import type { Rng } from './rng'
import { passiveById } from './passives'

export interface BaseDef {
  id: string
  name: string
  slot: Slot
  implicit: { stat: StatKey; value: number }
}

interface AffixDef {
  id: string
  name: string
  stat: StatKey
  min: number
  max: number
  kind: 'prefix' | 'suffix'
}

export const BASES: BaseDef[] = [
  { id: 'splinter', name: 'Ash Splinter', slot: 'weapon', implicit: { stat: 'damage', value: 5 } },
  { id: 'brand', name: 'Cinder Brand', slot: 'weapon', implicit: { stat: 'damage', value: 8 } },
  { id: 'vest', name: 'Coal Vest', slot: 'armor', implicit: { stat: 'life', value: 14 } },
  { id: 'mail', name: 'Kiln Mail', slot: 'armor', implicit: { stat: 'life', value: 24 } },
  { id: 'band', name: 'Ember Band', slot: 'ring', implicit: { stat: 'fireRes', value: 6 } },
  { id: 'loop', name: 'Gold Loop', slot: 'ring', implicit: { stat: 'crit', value: 0.03 } },
]

const AFFIX_POOL: AffixDef[] = [
  { id: 'keen', name: 'Keen', stat: 'damage', min: 2, max: 6, kind: 'prefix' },
  { id: 'heavy', name: 'Heavy', stat: 'damage', min: 3, max: 8, kind: 'prefix' },
  { id: 'vital', name: 'Vital', stat: 'life', min: 8, max: 22, kind: 'prefix' },
  { id: 'swift', name: 'of Swiftness', stat: 'attackSpeed', min: 0.04, max: 0.1, kind: 'suffix' },
  { id: 'precision', name: 'of Precision', stat: 'crit', min: 0.02, max: 0.06, kind: 'suffix' },
  { id: 'ash', name: 'of Ash', stat: 'fireRes', min: 6, max: 14, kind: 'suffix' },
  { id: 'vigor', name: 'of Vigor', stat: 'life', min: 6, max: 16, kind: 'suffix' },
]

const RARE_A = ['Quiet', 'Hollow', 'Gilded', 'Ashen', 'Broken', 'Living', 'Last', 'Dim']
const RARE_B = ['Brand', 'Vigil', 'Cinder', 'Oath', 'Hearth', 'Splinter', 'Crown', 'Vein']

const STAT_LABEL: Record<StatKey, string> = {
  damage: 'Damage',
  attackSpeed: 'Attack speed',
  crit: 'Crit',
  life: 'Life',
  fireRes: 'Fire res',
}

export function baseOf(id: string): BaseDef | undefined {
  return BASES.find((base) => base.id === id)
}

export function slotLabel(slot: Slot): string {
  if (slot === 'weapon') return 'Weapon'
  if (slot === 'armor') return 'Armor'
  return 'Ring'
}

export function statLabel(stat: StatKey): string {
  return STAT_LABEL[stat]
}

function pick<T>(rng: Rng, list: readonly T[]): T {
  return list[Math.floor(rng() * list.length)]
}

function roundAffix(stat: StatKey, value: number): number {
  if (stat === 'damage' || stat === 'life' || stat === 'fireRes') return Math.round(value)
  return Math.round(value * 100) / 100
}

export function rollAffixes(rarity: Rarity, rng: Rng): Affix[] {
  if (rarity === 'normal') return []
  const count = rarity === 'magic' ? (rng() < 0.45 ? 1 : 2) : rng() < 0.55 ? 3 : 4
  const picked: Affix[] = []
  const used = new Set<string>()
  for (let i = 0; i < count; i++) {
    const preferred = i % 2 === 0 ? 'prefix' : 'suffix'
    let choices = AFFIX_POOL.filter((affix) => affix.kind === preferred && !used.has(affix.id))
    if (choices.length === 0) choices = AFFIX_POOL.filter((affix) => !used.has(affix.id))
    if (choices.length === 0) break
    const def = pick(rng, choices)
    used.add(def.id)
    picked.push({
      id: def.id,
      name: def.name,
      stat: def.stat,
      value: roundAffix(def.stat, def.min + rng() * (def.max - def.min)),
    })
  }
  return picked
}

function itemTitle(baseName: string, rarity: Rarity, affixes: Affix[], rng: Rng): string {
  if (rarity === 'normal') return baseName
  if (rarity === 'rare') return `${pick(rng, RARE_A)} ${pick(rng, RARE_B)}`
  const pre = affixes.find((affix) => !affix.name.startsWith('of '))
  const suf = affixes.find((affix) => affix.name.startsWith('of '))
  return [pre?.name, baseName, suf?.name].filter(Boolean).join(' ')
}

export function rollBaseId(slot: Slot, mapIndex: number, rng: Rng): string {
  const pool = BASES.filter((base) => base.slot === slot)
  const better = mapIndex >= 1 && rng() < 0.35 + mapIndex * 0.2
  return (better ? pool[pool.length - 1] : pool[0]).id
}

export function rollItem(options: {
  rng: Rng
  id: string
  rarity: Rarity
  mapIndex?: number
  slot?: Slot
  baseId?: string
}): Item {
  const hinted = options.baseId ? baseOf(options.baseId) : undefined
  const slot = options.slot ?? hinted?.slot ?? 'weapon'
  const baseId = options.baseId ?? rollBaseId(slot, options.mapIndex ?? 0, options.rng)
  const base = baseOf(baseId) ?? BASES.find((entry) => entry.slot === slot) ?? BASES[0]
  const affixes = rollAffixes(options.rarity, options.rng)
  return {
    id: options.id,
    baseId: base.id,
    name: itemTitle(base.name, options.rarity, affixes, options.rng),
    slot: base.slot,
    rarity: options.rarity,
    affixes,
  }
}

function addStat(totals: Record<StatKey, number>, stat: StatKey, value: number) {
  totals[stat] += value
}

export function derive(hero: Hero): Derived {
  const totals: Record<StatKey, number> = {
    damage: 10 + (hero.level - 1) * 1.4,
    life: 140 + (hero.level - 1) * 12,
    attackSpeed: 0,
    crit: 0.05,
    fireRes: 0,
  }
  for (const item of Object.values(hero.equipped)) {
    if (!item) continue
    const base = baseOf(item.baseId)
    if (base) addStat(totals, base.implicit.stat, base.implicit.value)
    for (const affix of item.affixes) addStat(totals, affix.stat, affix.value)
  }
  for (const id of hero.allocated) {
    const node = passiveById(id)
    if (node) addStat(totals, node.stat, node.value)
  }
  return {
    maxLife: Math.round(totals.life),
    damage: Math.max(1, Math.round(totals.damage)),
    attackSpeed: Math.round(1.2 * (1 + totals.attackSpeed) * 100) / 100,
    crit: Math.min(0.6, totals.crit),
    fireRes: Math.min(75, totals.fireRes),
    critMultiplier: 1.5,
  }
}

const DERIVED_KEY: Record<StatKey, keyof Derived> = {
  damage: 'damage',
  attackSpeed: 'attackSpeed',
  crit: 'crit',
  life: 'maxLife',
  fireRes: 'fireRes',
}

export function compare(hero: Hero, item: Item): { stat: StatKey; delta: number }[] {
  const before = derive(hero)
  const after = derive({
    ...hero,
    equipped: { ...hero.equipped, [item.slot]: item },
  })
  const keys: StatKey[] = ['damage', 'attackSpeed', 'crit', 'life', 'fireRes']
  return keys
    .map((stat) => ({
      stat,
      delta: Number(after[DERIVED_KEY[stat]]) - Number(before[DERIVED_KEY[stat]]),
    }))
    .filter((row) => Math.abs(row.delta) > 0.001)
}

export function formatImplicit(stat: StatKey, value: number): string {
  if (stat === 'crit') return `+${Math.round(value * 100)}% crit`
  if (stat === 'fireRes') return `+${Math.round(value)} fire res`
  if (stat === 'attackSpeed') return `+${Math.round(value * 100)}% attack speed`
  if (stat === 'life') return `+${Math.round(value)} life`
  return `+${Math.round(value)} damage`
}

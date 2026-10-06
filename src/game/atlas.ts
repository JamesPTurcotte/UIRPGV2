import type { MapMod, MonsterKind } from './types'

export interface MapDef {
  id: string
  name: string
  blurb: string
  mod: MapMod
  count: number
  hp: number
  damage: number
  speed: number
  period: number
  kind: MonsterKind
  foe: string
  xp: number
}

export const MAPS: MapDef[] = [
  {
    id: 'ash',
    name: 'The Ash Vault',
    blurb: 'Monsters hit harder',
    mod: 'hits',
    count: 6,
    hp: 28,
    damage: 4,
    speed: 58,
    period: 1.28,
    kind: 'horn',
    foe: 'Crawler',
    xp: 12,
  },
  {
    id: 'gild',
    name: 'The Gilded Pit',
    blurb: 'More items drop',
    mod: 'loot',
    count: 7,
    hp: 40,
    damage: 5,
    speed: 62,
    period: 1.22,
    kind: 'hex',
    foe: 'Husk',
    xp: 16,
  },
  {
    id: 'spire',
    name: 'The Ember Spire',
    blurb: 'Monsters move faster',
    mod: 'haste',
    count: 8,
    hp: 56,
    damage: 6,
    speed: 64,
    period: 1.16,
    kind: 'wisp',
    foe: 'Wisp',
    xp: 20,
  },
]

export function mapById(id: string | null): MapDef | undefined {
  return MAPS.find((map) => map.id === id)
}

export function mapIndex(id: string | null): number {
  const index = MAPS.findIndex((map) => map.id === id)
  return index < 0 ? 0 : index
}

export function isUnlocked(id: string, cleared: Record<string, boolean>): boolean {
  const index = MAPS.findIndex((map) => map.id === id)
  if (index <= 0) return index === 0
  return Boolean(cleared[MAPS[index - 1].id])
}

export function nextAutoMap(cleared: Record<string, boolean>): string {
  const pending = MAPS.find((map) => !cleared[map.id])
  return pending ? pending.id : MAPS[MAPS.length - 1].id
}

export const ARENA = { w: 1700, h: 1100 }
export const HIDEOUT = { w: 1100, h: 800 }

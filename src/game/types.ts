export type Phase = 'title' | 'hideout' | 'map'
export type Slot = 'weapon' | 'armor' | 'ring'
export type Rarity = 'normal' | 'magic' | 'rare'
export type StatKey = 'damage' | 'attackSpeed' | 'crit' | 'life' | 'fireRes'
export type PanelId = 'character' | 'inventory' | 'craft' | 'atlas' | 'passives'
export type Currency = 'reroll' | 'upgrade'
export type MapMod = 'hits' | 'loot' | 'haste'
export type MonsterKind = 'horn' | 'hex' | 'wisp'
export type LogTone = 'info' | 'good' | 'bad' | 'magic' | 'rare' | 'normal'

export interface Affix {
  id: string
  name: string
  stat: StatKey
  value: number
}

export interface Item {
  id: string
  baseId: string
  name: string
  slot: Slot
  rarity: Rarity
  affixes: Affix[]
}

export interface Derived {
  maxLife: number
  damage: number
  attackSpeed: number
  crit: number
  fireRes: number
  critMultiplier: number
}

export interface Monster {
  id: string
  kind: MonsterKind
  name: string
  x: number
  y: number
  hp: number
  maxHp: number
  speed: number
  damage: number
  range: number
  attackPeriod: number
  attackTimer: number
  radius: number
  alive: boolean
  flash: number
}

export interface Drop {
  id: string
  x: number
  y: number
  rarity: Rarity | 'currency'
  item?: Item
  currency?: Currency
}

export interface FloatText {
  id: string
  x: number
  y: number
  text: string
  color: string
  life: number
  maxLife: number
}

export interface Nova {
  x: number
  y: number
  age: number
  duration: number
  radius: number
}

export interface LogLine {
  id: string
  text: string
  tone: LogTone
}

export interface DamageEvent {
  t: number
  amount: number
}

export interface Rock {
  x: number
  y: number
  rx: number
  ry: number
}

export interface Hero {
  level: number
  allocated: readonly string[]
  equipped: Partial<Record<Slot, Item>>
}

export interface GameState extends Hero {
  phase: Phase
  auto: boolean
  simTime: number
  xp: number
  passivePoints: number
  allocated: string[]
  rerollOrbs: number
  upgradeOrbs: number
  inventory: Item[]
  life: number
  mapId: string | null
  cleared: Record<string, boolean>
  playerX: number
  playerY: number
  facing: number
  clickTarget: { x: number; y: number } | null
  attackTimer: number
  novaTimer: number
  novaQueued: boolean
  monsters: Monster[]
  drops: Drop[]
  floats: FloatText[]
  novas: Nova[]
  trail: { x: number; y: number }[]
  rocks: Rock[]
  log: LogLine[]
  damageEvents: DamageEvent[]
  banner: string
  bannerLife: number
  summary: string
  summaryLife: number
  resolveName: string
  chainTimer: number
  clearHold: number
  shake: number
  hurt: number
  targetId: string | null
  hoverId: string | null
  hoverX: number
  hoverY: number
  panel: PanelId | null
  craftId: string | null
  uid: number
  rngState: number
  resolving: boolean
  fullNotice: boolean
  reducedMotion: boolean
  stuck: number
}

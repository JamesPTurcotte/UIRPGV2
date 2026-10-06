import type { GameState } from './types'
import { rand } from './rng'
import { derive, rollItem } from './items'

function nextId(g: { uid: number }, prefix: string): string {
  g.uid += 1
  return `${prefix}${g.uid}`
}

export function freshState(): GameState {
  const g: GameState = {
    phase: 'title',
    auto: true,
    simTime: 0,
    level: 1,
    xp: 0,
    passivePoints: 0,
    allocated: [],
    rerollOrbs: 2,
    upgradeOrbs: 2,
    inventory: [],
    equipped: {},
    life: 1,
    mapId: null,
    cleared: {},
    playerX: 550,
    playerY: 400,
    facing: -Math.PI / 2,
    clickTarget: null,
    attackTimer: 0,
    novaTimer: 0,
    novaQueued: false,
    monsters: [],
    drops: [],
    floats: [],
    novas: [],
    trail: [],
    rocks: [],
    log: [],
    damageEvents: [],
    banner: '',
    bannerLife: 0,
    summary: '',
    summaryLife: 0,
    resolveName: '',
    chainTimer: 0,
    clearHold: 0,
    shake: 0,
    hurt: 0,
    targetId: null,
    hoverId: null,
    hoverX: 0,
    hoverY: 0,
    panel: null,
    craftId: null,
    uid: 10,
    rngState: 42,
    resolving: false,
    fullNotice: false,
    reducedMotion: false,
    stuck: 0,
  }
  const rng = () => rand(g)
  g.equipped.weapon = rollItem({
    rng,
    id: nextId(g, 'it'),
    rarity: 'normal',
    slot: 'weapon',
    baseId: 'splinter',
  })
  g.inventory.push(
    rollItem({
      rng,
      id: nextId(g, 'it'),
      rarity: 'normal',
      slot: 'armor',
      baseId: 'vest',
    }),
  )
  g.inventory.push(
    rollItem({
      rng,
      id: nextId(g, 'it'),
      rarity: 'rare',
      slot: 'ring',
      baseId: 'band',
    }),
  )
  g.life = derive(g).maxLife
  return g
}

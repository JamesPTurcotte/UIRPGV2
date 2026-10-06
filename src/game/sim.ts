import type { Currency, Drop, GameState, Monster, PanelId, Rock, Slot } from './types'
import { ARENA, HIDEOUT, isUnlocked, mapById, mapIndex, nextAutoMap, type MapDef } from './atlas'
import { INVENTORY_SLOTS, NOVA_CD, PICKUP_RADIUS, PLAYER_RADIUS, PLAYER_RANGE, PLAYER_SPEED, REGEN, mitigate, strike, xpToNext } from './combat'
import { canReroll, canUpgrade, rerollRare, upgradeNormal } from './craft'
import { derive, rollBaseId, rollItem } from './items'
import { canAllocate } from './passives'
import { rand } from './rng'
import { audio } from '../audio/synth'
import { writeSave } from '../persist'

const EMPTY = new Set<string>()
const CLEAR_DELAY = 1.15

export interface Destination {
  kind: 'monster' | 'drop'
  id: string
  x: number
  y: number
  stop: number
}

function id(g: GameState, prefix: string): string {
  g.uid += 1
  return `${prefix}${g.uid}`
}

function pushLog(g: GameState, text: string, tone: GameState['log'][number]['tone']) {
  g.log = [{ id: id(g, 'l'), text, tone }, ...g.log].slice(0, 14)
}

function boundsOf(g: GameState) {
  return g.phase === 'map' ? ARENA : HIDEOUT
}

function hitsRock(x: number, y: number, radius: number, rock: Rock): boolean {
  const dx = (x - rock.x) / (rock.rx + radius)
  const dy = (y - rock.y) / (rock.ry + radius)
  return dx * dx + dy * dy < 1
}

function blocked(x: number, y: number, radius: number, rocks: Rock[], ignoreRocks: boolean): boolean {
  if (ignoreRocks) return false
  return rocks.some((rock) => hitsRock(x, y, radius, rock))
}

function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value))
}

function place(
  x: number,
  y: number,
  nx: number,
  ny: number,
  radius: number,
  rocks: Rock[],
  bounds: { w: number; h: number },
  ignoreRocks: boolean,
): { x: number; y: number } {
  const limit = (px: number, py: number) => ({
    x: clamp(px, radius, bounds.w - radius),
    y: clamp(py, radius, bounds.h - radius),
  })
  const direct = limit(nx, ny)
  if (!blocked(direct.x, direct.y, radius, rocks, ignoreRocks)) return direct
  const slideX = limit(nx, y)
  if (!blocked(slideX.x, slideX.y, radius, rocks, ignoreRocks)) return slideX
  const slideY = limit(x, ny)
  if (!blocked(slideY.x, slideY.y, radius, rocks, ignoreRocks)) return slideY
  return { x, y }
}

export function autoDestination(g: GameState): Destination | null {
  let best: Monster | null = null
  let bestDist = Infinity
  for (const monster of g.monsters) {
    if (!monster.alive) continue
    const distance = Math.hypot(monster.x - g.playerX, monster.y - g.playerY)
    if (distance < bestDist) {
      bestDist = distance
      best = monster
    }
  }
  if (best) return { kind: 'monster', id: best.id, x: best.x, y: best.y, stop: PLAYER_RANGE - 4 }
  if (g.inventory.length >= INVENTORY_SLOTS) return null
  let drop: Drop | null = null
  bestDist = Infinity
  for (const candidate of g.drops) {
    const distance = Math.hypot(candidate.x - g.playerX, candidate.y - g.playerY)
    if (distance < bestDist) {
      bestDist = distance
      drop = candidate
    }
  }
  if (!drop) return null
  return { kind: 'drop', id: drop.id, x: drop.x, y: drop.y, stop: 8 }
}

function moveToward(g: GameState, tx: number, ty: number, stop: number, dt: number, ignoreRocks: boolean) {
  const dx = tx - g.playerX
  const dy = ty - g.playerY
  const distance = Math.hypot(dx, dy)
  if (distance <= stop) return false
  const step = Math.min(distance - stop, PLAYER_SPEED * dt)
  const nx = g.playerX + (dx / distance) * step
  const ny = g.playerY + (dy / distance) * step
  const next = place(g.playerX, g.playerY, nx, ny, PLAYER_RADIUS, g.rocks, boundsOf(g), ignoreRocks)
  const movedX = next.x - g.playerX
  const movedY = next.y - g.playerY
  if (movedX !== 0 || movedY !== 0) g.facing = Math.atan2(movedY, movedX)
  g.playerX = next.x
  g.playerY = next.y
  const moved = Math.hypot(movedX, movedY)
  if (moved > 0.4) {
    g.trail = [...g.trail, { x: g.playerX, y: g.playerY }].slice(-16)
  }
  return moved > 0.4
}

function wishDir(held: ReadonlySet<string>): { x: number; y: number } | null {
  let x = 0
  let y = 0
  if (held.has('w') || held.has('arrowup')) y -= 1
  if (held.has('s') || held.has('arrowdown')) y += 1
  if (held.has('a') || held.has('arrowleft')) x -= 1
  if (held.has('d') || held.has('arrowright')) x += 1
  if (x === 0 && y === 0) return null
  const magnitude = Math.hypot(x, y)
  return { x: x / magnitude, y: y / magnitude }
}

function spawnRocks(g: GameState) {
  const rocks: Rock[] = []
  for (let i = 0; i < 7; i++) {
    const x = 140 + rand(g) * (ARENA.w - 280)
    const y = 140 + rand(g) * (ARENA.h - 280)
    if (Math.hypot(x - ARENA.w / 2, y - ARENA.h / 2) < 180) continue
    rocks.push({ x, y, rx: 34 + rand(g) * 30, ry: 22 + rand(g) * 20 })
  }
  g.rocks = rocks
}

function spawnMonsters(g: GameState, map: MapDef) {
  const monsters: Monster[] = []
  for (let i = 0; i < map.count; i++) {
    const angle = (i / map.count) * Math.PI * 2 + 0.35
    const radius = 380 + rand(g) * 90
    let x = clamp(ARENA.w / 2 + Math.cos(angle) * radius, 90, ARENA.w - 90)
    let y = clamp(ARENA.h / 2 + Math.sin(angle) * radius, 90, ARENA.h - 90)
    for (const rock of g.rocks) {
      if (hitsRock(x, y, 22, rock)) {
        x = clamp(x + 90, 90, ARENA.w - 90)
        y = clamp(y + 50, 90, ARENA.h - 90)
      }
    }
    const haste = map.mod === 'haste'
    const hp = map.hp
    monsters.push({
      id: id(g, 'm'),
      kind: map.kind,
      name: map.foe,
      x,
      y,
      hp,
      maxHp: hp,
      speed: map.speed * (haste ? 1.35 : 1),
      damage: map.damage,
      range: 44,
      attackPeriod: map.period / (haste ? 1.15 : 1),
      attackTimer: 0.45 + rand(g) * 0.5,
      radius: 16,
      alive: true,
      flash: 0,
    })
  }
  g.monsters = monsters
}

function grantXp(g: GameState, amount: number) {
  const before = derive(g).maxLife
  g.xp += amount
  let gained = 0
  while (g.xp >= xpToNext(g.level)) {
    g.xp -= xpToNext(g.level)
    g.level += 1
    g.passivePoints += 1
    gained += 1
  }
  if (!gained) return
  const after = derive(g).maxLife
  g.life = Math.min(after, g.life + (after - before))
  g.banner = `Level ${g.level}`
  g.bannerLife = 1.5
  pushLog(g, `Level ${g.level}. A passive point is waiting.`, 'good')
  audio.level()
}

function rollDeathDrop(g: GameState, monster: Monster) {
  const map = mapById(g.mapId)
  const mult = map?.mod === 'loot' ? 1.5 : 1
  const roll = rand(g)
  let rarity: Drop['rarity'] | null = null
  let currency: Currency | undefined
  if (roll < 0.06 * mult) rarity = 'rare'
  else if (roll < 0.18 * mult) rarity = 'magic'
  else if (roll < 0.38 * mult) rarity = 'normal'
  else if (roll < 0.5 * mult) {
    rarity = 'currency'
    currency = rand(g) < 0.5 ? 'reroll' : 'upgrade'
  }
  if (!rarity) return
  const drop: Drop = {
    id: id(g, 'd'),
    x: monster.x + (rand(g) - 0.5) * 16,
    y: monster.y + (rand(g) - 0.5) * 16,
    rarity,
    currency,
  }
  if (rarity !== 'currency') {
    const slots = ['weapon', 'armor', 'ring'] as const
    const slot = slots[Math.floor(rand(g) * slots.length)]
    drop.item = rollItem({
      rng: () => rand(g),
      id: id(g, 'it'),
      rarity,
      slot,
      baseId: rollBaseId(slot, mapIndex(g.mapId), () => rand(g)),
      mapIndex: mapIndex(g.mapId),
    })
  }
  g.drops = [...g.drops, drop]
  if (rarity === 'rare' && !g.reducedMotion) g.shake = 5
}

function floatText(g: GameState, x: number, y: number, text: string, color: string) {
  g.floats = [
    ...g.floats,
    { id: id(g, 'f'), x, y, text, color, life: 0.7, maxLife: 0.7 },
  ].slice(-36)
}

function hurtMonster(g: GameState, monster: Monster, amount: number, crit: boolean) {
  monster.hp -= amount
  monster.flash = 0.12
  g.damageEvents = [...g.damageEvents, { t: g.simTime, amount }].slice(-160)
  floatText(g, monster.x, monster.y - 22, crit ? `${amount}!` : `${amount}`, crit ? '#ffd56a' : '#f4efe6')
  if (monster.hp > 0) {
    audio.hit()
    if (crit) pushLog(g, `Critical hit for ${amount}.`, 'good')
    return
  }
  monster.hp = 0
  monster.alive = false
  const map = mapById(g.mapId)
  grantXp(g, map?.xp ?? 10)
  const before = g.drops.length
  rollDeathDrop(g, monster)
  const drop = g.drops[g.drops.length - 1]
  if (g.drops.length > before && drop) {
    if (drop.item) {
      pushLog(g, `${drop.item.rarity === 'rare' ? 'Rare' : drop.item.rarity === 'magic' ? 'Magic' : 'Normal'} drop: ${drop.item.name}.`, drop.item.rarity)
      audio.drop(drop.item.rarity)
    } else {
      pushLog(g, drop.currency === 'reroll' ? 'Ash Salt drops.' : 'Kindling drops.', 'info')
      audio.drop('currency')
    }
  }
  pushLog(g, `${monster.name} falls.`, 'info')
  audio.hit()
}

function die(g: GameState) {
  const name = mapById(g.mapId)?.name ?? 'the map'
  g.life = 0
  g.auto = false
  g.summary = `You fell in ${name}.`
  g.summaryLife = 8
  g.targetId = null
  pushLog(g, `You fell in ${name}.`, 'bad')
  audio.death()
  enterHideout(g)
  writeSave(g)
}

function hurtPlayer(g: GameState, raw: number): boolean {
  const map = mapById(g.mapId)
  const hitsMod = map?.mod === 'hits' ? 1.35 : 1
  const taken = mitigate(raw, derive(g).fireRes, hitsMod)
  g.life -= taken
  g.hurt = 0.16
  if (!g.reducedMotion) g.shake = Math.max(g.shake, 2.4)
  floatText(g, g.playerX, g.playerY - 26, `${taken}`, '#ff8d7a')
  pushLog(g, `Hit for ${taken}.`, 'bad')
  audio.hurt()
  if (g.life <= 0) {
    die(g)
    return true
  }
  return false
}

function castNova(g: GameState) {
  if (g.novaTimer > 0 || g.phase !== 'map' || g.resolving) return
  const stats = derive(g)
  g.novaTimer = NOVA_CD
  g.novaQueued = false
  const radius = 118
  g.novas = [...g.novas, { x: g.playerX, y: g.playerY, age: 0, duration: 0.38, radius }]
  let hits = 0
  for (const monster of g.monsters) {
    if (!monster.alive) continue
    if (Math.hypot(monster.x - g.playerX, monster.y - g.playerY) <= radius + monster.radius) {
      const blow = strike(stats.damage * 1.55, stats.crit, stats.critMultiplier, () => rand(g))
      hurtMonster(g, monster, blow.amount, blow.crit)
      hits += 1
      if (!monster.alive && g.phase !== 'map') return
    }
  }
  audio.nova()
  if (hits > 0) pushLog(g, `Nova hits ${hits}.`, 'info')
}

function pickup(g: GameState, drop: Drop): boolean {
  if (drop.currency) {
    if (drop.currency === 'reroll') g.rerollOrbs += 1
    else g.upgradeOrbs += 1
    pushLog(g, drop.currency === 'reroll' ? 'Picked up Ash Salt.' : 'Picked up Kindling.', 'good')
    audio.drop('currency')
    return true
  }
  if (!drop.item) return true
  if (g.inventory.length >= INVENTORY_SLOTS) {
    if (!g.fullNotice) {
      g.fullNotice = true
      pushLog(g, 'Inventory is full.', 'bad')
    }
    return false
  }
  g.inventory = [...g.inventory, drop.item]
  g.fullNotice = false
  pushLog(g, `Picked up ${drop.item.name}.`, drop.item.rarity)
  audio.drop(drop.item.rarity)
  return true
}

function collectNear(g: GameState) {
  const kept: Drop[] = []
  for (const drop of g.drops) {
    if (Math.hypot(drop.x - g.playerX, drop.y - g.playerY) <= PICKUP_RADIUS) {
      if (!pickup(g, drop)) kept.push(drop)
    } else {
      kept.push(drop)
    }
  }
  g.drops = kept
}

function vacuum(g: GameState) {
  const kept: Drop[] = []
  for (const drop of g.drops) {
    if (!pickup(g, drop)) kept.push(drop)
  }
  g.drops = kept
}

function startResolve(g: GameState) {
  const map = mapById(g.mapId)
  const name = map?.name ?? 'The map'
  vacuum(g)
  g.resolving = true
  g.resolveName = name
  g.chainTimer = CLEAR_DELAY
  g.clearHold = 0
  g.cleared = { ...g.cleared, [g.mapId ?? '']: true }
  g.banner = `${name} cleared`
  g.bannerLife = CLEAR_DELAY
  g.monsters = []
  g.drops = []
  g.targetId = null
  g.clickTarget = null
  pushLog(g, `${name} is clear.`, 'good')
  audio.clear()
  writeSave(g)
}

function separateMonsters(g: GameState) {
  const monsters = g.monsters
  for (let i = 0; i < monsters.length; i++) {
    for (let j = i + 1; j < monsters.length; j++) {
      const a = monsters[i]
      const b = monsters[j]
      if (!a.alive || !b.alive) continue
      const dx = a.x - b.x
      const dy = a.y - b.y
      const distance = Math.hypot(dx, dy) || 0.001
      const min = a.radius + b.radius
      if (distance >= min) continue
      const push = (min - distance) / 2
      a.x += (dx / distance) * push
      a.y += (dy / distance) * push
      b.x -= (dx / distance) * push
      b.y -= (dy / distance) * push
    }
  }
}

function decayVisuals(g: GameState, dt: number) {
  g.simTime += dt
  g.bannerLife = Math.max(0, g.bannerLife - dt)
  if (g.bannerLife <= 0 && !g.resolving) g.banner = ''
  g.shake = Math.max(0, g.shake - dt * 10)
  g.hurt = Math.max(0, g.hurt - dt)
  g.floats = g.floats
    .map((entry) => ({ ...entry, life: entry.life - dt, y: entry.y - 28 * dt }))
    .filter((entry) => entry.life > 0)
  g.novas = g.novas
    .map((nova) => ({ ...nova, age: nova.age + dt }))
    .filter((nova) => nova.age < nova.duration)
  for (const monster of g.monsters) monster.flash = Math.max(0, monster.flash - dt)
  if (g.summary && g.phase === 'hideout') {
    g.summaryLife -= dt
    if (g.summaryLife <= 0) g.summary = ''
  }
}

export function enterHideout(g: GameState) {
  g.phase = 'hideout'
  g.mapId = null
  g.resolving = false
  g.chainTimer = 0
  g.clearHold = 0
  g.monsters = []
  g.drops = []
  g.novas = []
  g.rocks = []
  g.floats = []
  g.clickTarget = null
  g.targetId = null
  g.stuck = 0
  g.playerX = HIDEOUT.w / 2
  g.playerY = HIDEOUT.h / 2
  g.life = derive(g).maxLife
  g.banner = ''
  g.bannerLife = 0
  audio.setMood('hideout')
}

export function enterMap(g: GameState, mapId: string) {
  const map = mapById(mapId)
  if (!map || !isUnlocked(mapId, g.cleared)) return
  g.phase = 'map'
  g.mapId = map.id
  g.summary = ''
  g.summaryLife = 0
  g.resolving = false
  g.chainTimer = 0
  g.clearHold = 0
  g.fullNotice = false
  g.clickTarget = null
  g.targetId = null
  g.stuck = 0
  g.floats = []
  g.novas = []
  g.trail = []
  g.drops = []
  g.playerX = ARENA.w / 2
  g.playerY = ARENA.h / 2
  g.facing = -Math.PI / 2
  g.attackTimer = 0.3
  g.novaTimer = 0.9
  g.novaQueued = false
  spawnRocks(g)
  spawnMonsters(g, map)
  g.life = derive(g).maxLife
  g.banner = map.name
  g.bannerLife = 1.7
  pushLog(g, `Entered ${map.name}.`, 'info')
  audio.setMood(map.id as 'ash' | 'gild' | 'spire')
  writeSave(g)
}

export function begin(g: GameState) {
  if (g.phase !== 'title') return
  audio.unlock()
  if (typeof matchMedia !== 'undefined') {
    g.reducedMotion = matchMedia('(prefers-reduced-motion: reduce)').matches
  }
  if (g.auto) enterMap(g, nextAutoMap(g.cleared))
  else enterHideout(g)
}

export function toggleAuto(g: GameState) {
  g.auto = !g.auto
  g.clickTarget = null
  if (!g.auto) g.targetId = null
  audio.ui()
  writeSave(g)
  if (g.auto && g.phase === 'hideout') enterMap(g, nextAutoMap(g.cleared))
}

export function togglePanel(g: GameState, panel: PanelId) {
  g.panel = g.panel === panel ? null : panel
  g.hoverId = null
  audio.open()
}

export function closePanel(g: GameState) {
  if (!g.panel) return
  g.panel = null
  g.hoverId = null
  audio.ui()
}

export function setHover(g: GameState, itemId: string | null, x = 0, y = 0) {
  g.hoverId = itemId
  g.hoverX = x
  g.hoverY = y
}

export function dismissSummary(g: GameState) {
  g.summary = ''
  g.summaryLife = 0
}

export function setClickTarget(g: GameState, x: number, y: number) {
  if (g.auto || g.resolving || (g.phase !== 'map' && g.phase !== 'hideout')) return
  g.clickTarget = { x, y }
}

export function queueNova(g: GameState) {
  if (g.phase !== 'map' || g.resolving) return
  if (g.novaTimer <= 0) castNova(g)
  else g.novaQueued = true
}

export function findItem(g: GameState, itemId: string) {
  return (
    g.inventory.find((item) => item.id === itemId) ??
    Object.values(g.equipped).find((item) => item?.id === itemId)
  )
}

export function equip(g: GameState, itemId: string) {
  const index = g.inventory.findIndex((item) => item.id === itemId)
  if (index < 0) return
  const item = g.inventory[index]
  const previous = g.equipped[item.slot]
  const next = g.inventory.filter((_, itemIndex) => itemIndex !== index)
  if (previous) next.push(previous)
  g.inventory = next
  g.equipped = { ...g.equipped, [item.slot]: item }
  g.fullNotice = false
  audio.ui()
  writeSave(g)
}

export function unequip(g: GameState, slot: Slot) {
  const item = g.equipped[slot]
  if (!item || g.inventory.length >= INVENTORY_SLOTS) return
  const equipped = { ...g.equipped }
  delete equipped[slot]
  g.equipped = equipped
  g.inventory = [...g.inventory, item]
  audio.ui()
  writeSave(g)
}

function replaceInventoryItem(g: GameState, itemId: string, nextItem: GameState['inventory'][number]) {
  g.inventory = g.inventory.map((item) => (item.id === itemId ? nextItem : item))
  if (g.craftId === itemId) g.craftId = nextItem.id
}

export function useUpgrade(g: GameState, itemId: string) {
  const item = g.inventory.find((entry) => entry.id === itemId)
  if (!item || !canUpgrade(item) || g.upgradeOrbs <= 0) return
  g.upgradeOrbs -= 1
  const next = upgradeNormal(item, () => rand(g))
  replaceInventoryItem(g, itemId, next)
  pushLog(g, `Kindling lifts ${next.name}.`, 'magic')
  audio.craft()
  writeSave(g)
}

export function useReroll(g: GameState, itemId: string) {
  const item = g.inventory.find((entry) => entry.id === itemId)
  if (!item || !canReroll(item) || g.rerollOrbs <= 0) return
  g.rerollOrbs -= 1
  const next = rerollRare(item, () => rand(g))
  replaceInventoryItem(g, itemId, next)
  pushLog(g, `Ash Salt rerolls ${next.name}.`, 'rare')
  audio.craft()
  writeSave(g)
}

export function selectCraft(g: GameState, itemId: string | null) {
  g.craftId = itemId
}

export function allocate(g: GameState, nodeId: string) {
  if (!canAllocate(nodeId, g.allocated, g.passivePoints)) return
  g.allocated = [...g.allocated, nodeId]
  g.passivePoints -= 1
  const before = derive({ ...g, allocated: g.allocated.filter((id) => id !== nodeId) }).maxLife
  const after = derive(g).maxLife
  g.life = Math.min(after, g.life + Math.max(0, after - before))
  audio.ui()
  writeSave(g)
}

export function refundPassives(g: GameState) {
  if (g.phase !== 'hideout' || g.allocated.length === 0) return
  g.passivePoints += g.allocated.length
  g.allocated = []
  const after = derive(g).maxLife
  g.life = Math.min(after, g.life)
  audio.ui()
  writeSave(g)
}

export function openMap(g: GameState, mapId: string) {
  if (g.auto || g.phase !== 'hideout' || !isUnlocked(mapId, g.cleared)) return
  enterMap(g, mapId)
}

export function leaveMap(g: GameState) {
  if (g.auto || g.phase !== 'map') return
  const name = mapById(g.mapId)?.name ?? 'the map'
  pushLog(g, `Left ${name}.`, 'info')
  enterHideout(g)
  writeSave(g)
}

function finishChain(g: GameState) {
  const name = g.resolveName
  g.resolving = false
  g.chainTimer = 0
  if (g.auto) {
    enterMap(g, nextAutoMap(g.cleared))
    return
  }
  g.summary = `${name} is clear.`
  g.summaryLife = 8
  enterHideout(g)
}

export function step(g: GameState, dt: number, keys: ReadonlySet<string> = EMPTY) {
  const frame = Math.min(0.05, Math.max(0, dt))
  if (g.phase === 'title' || frame === 0) return
  decayVisuals(g, frame)

  if (g.resolving) {
    g.chainTimer -= frame
    if (g.chainTimer <= 0) finishChain(g)
    return
  }

  if (g.phase === 'hideout') {
    if (g.auto) {
      enterMap(g, nextAutoMap(g.cleared))
      return
    }
    steer(g, frame, keys)
    return
  }

  if (g.novaTimer > 0) g.novaTimer = Math.max(0, g.novaTimer - frame)
  steer(g, frame, keys)
  collectNear(g)
  if (g.phase !== 'map') return

  const stats = derive(g)
  g.attackTimer -= frame
  let nearest: Monster | null = null
  let nearestDist = PLAYER_RANGE
  for (const monster of g.monsters) {
    if (!monster.alive) continue
    const distance = Math.hypot(monster.x - g.playerX, monster.y - g.playerY)
    if (distance <= nearestDist) {
      nearestDist = distance
      nearest = monster
    }
  }
  if (nearest && g.attackTimer <= 0) {
    g.attackTimer = 1 / stats.attackSpeed
    const blow = strike(stats.damage, stats.crit, stats.critMultiplier, () => rand(g))
    hurtMonster(g, nearest, blow.amount, blow.crit)
  }

  const novaTarget = g.monsters.some(
    (monster) => monster.alive && Math.hypot(monster.x - g.playerX, monster.y - g.playerY) <= 118,
  )
  if (g.novaTimer <= 0 && (g.novaQueued || (g.auto && novaTarget))) castNova(g)

  const aggro = 200
  for (const monster of g.monsters) {
    if (!monster.alive) continue
    const dx = g.playerX - monster.x
    const dy = g.playerY - monster.y
    const distance = Math.hypot(dx, dy) || 0.001
    if (distance < aggro && distance > monster.range) {
      const stepDist = Math.min(distance - monster.range, monster.speed * frame)
      const nx = monster.x + (dx / distance) * stepDist
      const ny = monster.y + (dy / distance) * stepDist
      const next = place(monster.x, monster.y, nx, ny, monster.radius, g.rocks, ARENA, false)
      monster.x = next.x
      monster.y = next.y
    }
    if (distance <= monster.range + 6) {
      monster.attackTimer -= frame
      if (monster.attackTimer <= 0) {
        monster.attackTimer = monster.attackPeriod
        if (hurtPlayer(g, monster.damage)) return
      }
    }
  }
  separateMonsters(g)

  const maxLife = derive(g).maxLife
  if (g.life > 0 && g.life < maxLife) g.life = Math.min(maxLife, g.life + REGEN * frame)

  const alive = g.monsters.some((monster) => monster.alive)
  if (!g.monsters.length || alive) {
    g.clearHold = 0
    return
  }
  const canLoot = g.inventory.length < INVENTORY_SLOTS && g.drops.length > 0
  if (g.auto && canLoot) {
    g.clearHold = 0
    return
  }
  g.clearHold += frame
  const wait = g.drops.length > 0 ? 1.2 : 0.4
  if (g.clearHold >= wait) startResolve(g)
}

function steer(g: GameState, dt: number, keys: ReadonlySet<string>) {
  if (g.auto && g.phase === 'map') {
    const dest = autoDestination(g)
    g.targetId = dest?.kind === 'monster' ? dest.id : null
    if (!dest) {
      g.stuck = 0
      return
    }
    const ignore = g.stuck > 0.7
    const moved = moveToward(g, dest.x, dest.y, dest.stop, dt, ignore)
    g.stuck = moved ? 0 : g.stuck + dt
    return
  }

  g.targetId = null
  const wish = wishDir(keys)
  if (wish) {
    g.clickTarget = null
    const nx = g.playerX + wish.x * PLAYER_SPEED * dt
    const ny = g.playerY + wish.y * PLAYER_SPEED * dt
    const beforeX = g.playerX
    const beforeY = g.playerY
    const next = place(g.playerX, g.playerY, nx, ny, PLAYER_RADIUS, g.rocks, boundsOf(g), false)
    g.playerX = next.x
    g.playerY = next.y
    if (next.x !== beforeX || next.y !== beforeY) {
      g.facing = Math.atan2(next.y - beforeY, next.x - beforeX)
      g.trail = [...g.trail, { x: g.playerX, y: g.playerY }].slice(-16)
    }
    return
  }
  if (!g.clickTarget) return
  const arrived = !moveToward(g, g.clickTarget.x, g.clickTarget.y, 8, dt, false)
  if (arrived) g.clickTarget = null
}

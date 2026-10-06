import { describe, expect, it } from 'vitest'
import { isUnlocked, nextAutoMap } from './atlas'
import { dpsBuckets, mitigate, rollingDps, strike, xpToNext } from './combat'
import { canReroll, canUpgrade, rerollRare, upgradeNormal } from './craft'
import { compare, derive, rollAffixes, rollItem } from './items'
import { canAllocate } from './passives'
import { mulberry32 } from './rng'
import { freshState } from './state'
import { applySave, toSave } from '../persist'
import { autoDestination, begin, enterHideout, enterMap, setClickTarget, step, useUpgrade } from './sim'

describe('combat rules', () => {
  it('asks for more experience each level', () => {
    expect(xpToNext(1)).toBeLessThan(xpToNext(2))
    expect(xpToNext(3)).toBe(36 + 3 * 18)
  })

  it('keeps hits at least 1 and sometimes crits', () => {
    const rng = mulberry32(7)
    const hits = Array.from({ length: 40 }, () => strike(10, 1, 1.5, rng))
    expect(hits.every((hit) => hit.amount >= 1 && hit.crit)).toBe(true)
    const soft = strike(10, 0, 1.5, mulberry32(1))
    expect(soft.crit).toBe(false)
  })

  it('lets fire res soften a hit and a map modifier worsen it', () => {
    expect(mitigate(10, 0, 1)).toBe(10)
    expect(mitigate(10, 50, 1)).toBeLessThan(10)
    expect(mitigate(10, 0, 1.35)).toBeGreaterThan(10)
  })

  it('builds a dps window from recent hits', () => {
    const events = [
      { t: 9.2, amount: 10 },
      { t: 8, amount: 6 },
    ]
    expect(rollingDps(events, 10, 4)).toBeCloseTo(4)
    const buckets = dpsBuckets(events, 10, 10, 10)
    expect(buckets.some((value) => value > 0)).toBe(true)
  })
})

describe('items and crafting', () => {
  it('rolls affix counts from the rarity', () => {
    const rng = mulberry32(3)
    for (let i = 0; i < 30; i++) {
      expect(rollAffixes('normal', rng)).toHaveLength(0)
      const magic = rollAffixes('magic', rng).length
      const rare = rollAffixes('rare', rng).length
      expect(magic === 1 || magic === 2).toBe(true)
      expect(rare === 3 || rare === 4).toBe(true)
    }
  })

  it('keeps the base when a rare is rerolled or a normal is lifted', () => {
    const rng = mulberry32(11)
    const rare = rollItem({ rng, id: 'a', rarity: 'rare', slot: 'ring', baseId: 'band' })
    const again = rerollRare(rare, rng)
    expect(again.rarity).toBe('rare')
    expect(again.baseId).toBe('band')
    expect(again.id).toBe('a')
    expect(again.affixes.length).toBeGreaterThanOrEqual(3)

    const normal = rollItem({ rng, id: 'b', rarity: 'normal', slot: 'armor', baseId: 'vest' })
    expect(canUpgrade(normal)).toBe(true)
    expect(canReroll(normal)).toBe(false)
    expect(canUpgrade(rare)).toBe(false)
    expect(canReroll(rare)).toBe(true)
    const magic = upgradeNormal(normal, rng)
    expect(magic.rarity).toBe('magic')
    expect(magic.baseId).toBe('vest')
    expect(magic.affixes.length).toBeGreaterThan(0)
  })

  it('shows a damage gain when a stronger weapon replaces the equipped one', () => {
    const hero = freshState()
    const rng = mulberry32(4)
    const weapon = rollItem({ rng, id: 'big', rarity: 'rare', slot: 'weapon', baseId: 'brand' })
    weapon.affixes = [{ id: 'heavy', name: 'Heavy', stat: 'damage', value: 8 }]
    const rows = compare(hero, weapon)
    const damage = rows.find((row) => row.stat === 'damage')
    expect(damage && damage.delta).toBeGreaterThan(0)
    expect(derive(hero).maxLife).toBeGreaterThan(100)
  })
})

describe('atlas', () => {
  it('unlocks maps in order and loops the last one', () => {
    expect(isUnlocked('ash', {})).toBe(true)
    expect(isUnlocked('gild', {})).toBe(false)
    expect(isUnlocked('gild', { ash: true })).toBe(true)
    expect(isUnlocked('spire', { ash: true })).toBe(false)
    expect(isUnlocked('spire', { ash: true, gild: true })).toBe(true)
    expect(nextAutoMap({})).toBe('ash')
    expect(nextAutoMap({ ash: true })).toBe('gild')
    expect(nextAutoMap({ ash: true, gild: true, spire: true })).toBe('spire')
  })

  it('only offers a node when its parent is taken', () => {
    expect(canAllocate('n1', [], 1)).toBe(true)
    expect(canAllocate('n2', [], 1)).toBe(false)
    expect(canAllocate('n2', ['n1'], 1)).toBe(true)
    expect(canAllocate('n1', ['n1'], 1)).toBe(false)
  })
})

describe('the character playing', () => {
  it('starts in auto and walks into the first map', () => {
    const g = freshState()
    expect(g.auto).toBe(true)
    begin(g)
    expect(g.phase).toBe('map')
    expect(g.mapId).toBe('ash')
    expect(g.monsters.length).toBeGreaterThan(0)
  })

  it('chases the closer monster and ignores a click while auto is on', () => {
    const g = freshState()
    enterMap(g, 'ash')
    const dest = autoDestination(g)
    expect(dest?.kind).toBe('monster')
    const before = Math.hypot((dest?.x ?? 0) - g.playerX, (dest?.y ?? 0) - g.playerY)
    setClickTarget(g, 10, 10)
    expect(g.clickTarget).toBeNull()
    for (let i = 0; i < 20; i++) step(g, 0.05)
    const after = Math.hypot((dest?.x ?? 0) - g.playerX, (dest?.y ?? 0) - g.playerY)
    expect(after).toBeLessThan(before)
  })

  it('moves by hand when auto is off', () => {
    const g = freshState()
    enterHideout(g)
    g.auto = false
    const start = g.playerX
    const keys = new Set(['d'])
    for (let i = 0; i < 10; i++) step(g, 0.05, keys)
    expect(g.playerX).toBeGreaterThan(start)
  })

  it('clears the vault on its own and opens the next map', () => {
    const g = freshState()
    enterMap(g, 'ash')
    for (let i = 0; i < 1200; i++) step(g, 0.05)
    expect(g.cleared.ash, `life ${g.life} phase ${g.phase} map ${g.mapId}`).toBe(true)
    expect(g.mapId).toBe('gild')
    expect(g.level).toBeGreaterThan(1)
  })

  it('stops auto after a death', () => {
    const g = freshState()
    enterMap(g, 'ash')
    const foe = g.monsters[0]
    foe.x = g.playerX
    foe.y = g.playerY
    foe.damage = 500
    foe.attackTimer = 0
    for (let i = 0; i < 5; i++) step(g, 0.05)
    expect(g.phase).toBe('hideout')
    expect(g.auto).toBe(false)
    expect(g.summary).toContain('fell')
  })

  it('lets the player lift a normal item', () => {
    const g = freshState()
    const vest = g.inventory.find((item) => item.baseId === 'vest')
    expect(vest?.rarity).toBe('normal')
    useUpgrade(g, vest!.id)
    const lifted = g.inventory.find((item) => item.id === vest!.id)
    expect(lifted?.rarity).toBe('magic')
    expect(g.upgradeOrbs).toBe(1)
  })
})

describe('save', () => {
  it('keeps manual control when that is what was stored', () => {
    const g = freshState()
    g.auto = false
    g.level = 4
    g.passivePoints = 2
    const restored = freshState()
    applySave(restored, toSave(g))
    expect(restored.auto).toBe(false)
    expect(restored.level).toBe(4)
    expect(restored.passivePoints).toBe(2)
    expect(restored.phase).toBe('title')
    applySave(restored, null)
    expect(restored.level).toBe(4)
  })
})

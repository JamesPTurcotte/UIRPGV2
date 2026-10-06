import { ARENA, HIDEOUT } from '../game/atlas'
import type { GameState, Monster, Rock } from '../game/types'

const ZOOM = 1.7
let camX = 0
let camY = 0

export function screenToWorld(x: number, y: number, width: number, height: number): { x: number; y: number } {
  return {
    x: (x - width / 2) / ZOOM + camX,
    y: (y - height / 2) / ZOOM + camY,
  }
}

export function resizeCanvas(canvas: HTMLCanvasElement): { width: number; height: number; dpr: number } {
  const rect = canvas.getBoundingClientRect()
  const dpr = Math.min(2, window.devicePixelRatio || 1)
  const width = Math.max(1, rect.width)
  const height = Math.max(1, rect.height)
  canvas.width = Math.floor(width * dpr)
  canvas.height = Math.floor(height * dpr)
  return { width, height, dpr }
}

function clampCenter(value: number, view: number, bound: number): number {
  if (bound <= view) return bound / 2
  return Math.min(bound - view / 2, Math.max(view / 2, value))
}

function floorColors(g: GameState): [string, string] {
  if (g.phase !== 'map') return ['#17130f', '#0c0b09']
  if (g.mapId === 'gild') return ['#1c170f', '#0e0c09']
  if (g.mapId === 'spire') return ['#1c110e', '#0c0908']
  return ['#181410', '#0c0b09']
}

export function draw(ctx: CanvasRenderingContext2D, width: number, height: number, dpr: number, g: GameState) {
  const bounds = g.phase === 'map' ? ARENA : HIDEOUT
  const viewW = width / ZOOM
  const viewH = height / ZOOM
  const focusX = clampCenter(g.playerX, viewW, bounds.w)
  const focusY = clampCenter(g.playerY, viewH, bounds.h)
  camX += (focusX - camX) * (g.reducedMotion ? 1 : 0.12)
  camY += (focusY - camY) * (g.reducedMotion ? 1 : 0.12)

  const shake = g.reducedMotion ? 0 : g.shake
  const sx = shake ? Math.sin(g.simTime * 40) * shake : 0
  const sy = shake ? Math.cos(g.simTime * 36) * shake : 0

  ctx.setTransform(dpr, 0, 0, dpr, 0, 0)
  ctx.clearRect(0, 0, width, height)
  const [inner, outer] = floorColors(g)
  const bg = ctx.createLinearGradient(0, 0, 0, height)
  bg.addColorStop(0, inner)
  bg.addColorStop(1, outer)
  ctx.fillStyle = bg
  ctx.fillRect(0, 0, width, height)

  ctx.save()
  ctx.translate(sx, sy)
  ctx.translate(width / 2, height / 2)
  ctx.scale(ZOOM, ZOOM)
  ctx.translate(-camX, -camY)

  const left = camX - viewW / 2
  const top = camY - viewH / 2
  ctx.strokeStyle = 'rgba(232, 196, 140, 0.06)'
  ctx.lineWidth = 1
  const startX = Math.floor(left / 48) * 48
  const startY = Math.floor(top / 48) * 48
  ctx.beginPath()
  for (let x = startX; x < left + viewW + 48; x += 48) {
    ctx.moveTo(x, top)
    ctx.lineTo(x, top + viewH)
  }
  for (let y = startY; y < top + viewH + 48; y += 48) {
    ctx.moveTo(left, y)
    ctx.lineTo(left + viewW, y)
  }
  ctx.stroke()

  if (g.phase === 'hideout') drawHideout(ctx)
  for (const rock of g.rocks) drawRock(ctx, rock)
  for (const drop of g.drops) drawDrop(ctx, g, drop.x, drop.y, drop.rarity)
  for (const monster of g.monsters) drawMonster(ctx, monster)

  if (g.auto && g.targetId) {
    const target = g.monsters.find((monster) => monster.id === g.targetId && monster.alive)
    if (target) drawTarget(ctx, g, target.x, target.y)
  }
  if (!g.auto && g.clickTarget) {
    ctx.strokeStyle = '#e8a15a'
    ctx.lineWidth = 1.5
    ctx.beginPath()
    ctx.arc(g.clickTarget.x, g.clickTarget.y, 14, 0, Math.PI * 2)
    ctx.moveTo(g.clickTarget.x - 20, g.clickTarget.y)
    ctx.lineTo(g.clickTarget.x + 20, g.clickTarget.y)
    ctx.moveTo(g.clickTarget.x, g.clickTarget.y - 20)
    ctx.lineTo(g.clickTarget.x, g.clickTarget.y + 20)
    ctx.stroke()
  }

  drawTrail(ctx, g)
  for (const nova of g.novas) {
    const t = nova.age / nova.duration
    ctx.beginPath()
    ctx.arc(nova.x, nova.y, nova.radius * t, 0, Math.PI * 2)
    ctx.strokeStyle = `rgba(255, 150, 70, ${0.7 * (1 - t)})`
    ctx.lineWidth = 3
    ctx.stroke()
  }
  drawPlayer(ctx, g)

  ctx.font = '600 14px "Source Sans 3", sans-serif'
  ctx.textAlign = 'center'
  for (const floater of g.floats) {
    ctx.globalAlpha = Math.max(0, floater.life / floater.maxLife)
    ctx.fillStyle = floater.color
    ctx.fillText(floater.text, floater.x, floater.y)
  }
  ctx.globalAlpha = 1
  ctx.restore()

  const vignette = ctx.createRadialGradient(width / 2, height / 2, width * 0.3, width / 2, height / 2, width * 0.72)
  vignette.addColorStop(0, 'rgba(0,0,0,0)')
  vignette.addColorStop(1, 'rgba(0,0,0,0.45)')
  ctx.fillStyle = vignette
  ctx.fillRect(0, 0, width, height)
}

function drawHideout(ctx: CanvasRenderingContext2D) {
  ctx.strokeStyle = 'rgba(232, 161, 90, 0.18)'
  ctx.lineWidth = 2
  ctx.beginPath()
  ctx.arc(HIDEOUT.w / 2, HIDEOUT.h / 2, 92, 0, Math.PI * 2)
  ctx.stroke()
  const braziers = [
    [HIDEOUT.w / 2 - 180, HIDEOUT.h / 2],
    [HIDEOUT.w / 2 + 180, HIDEOUT.h / 2],
    [HIDEOUT.w / 2, HIDEOUT.h / 2 - 150],
    [HIDEOUT.w / 2, HIDEOUT.h / 2 + 150],
  ]
  for (const [x, y] of braziers) {
    const glow = ctx.createRadialGradient(x, y, 2, x, y, 36)
    glow.addColorStop(0, 'rgba(255, 140, 60, 0.55)')
    glow.addColorStop(1, 'rgba(255, 140, 60, 0)')
    ctx.fillStyle = glow
    ctx.beginPath()
    ctx.arc(x, y, 36, 0, Math.PI * 2)
    ctx.fill()
  }
}

function drawRock(ctx: CanvasRenderingContext2D, rock: Rock) {
  ctx.beginPath()
  ctx.ellipse(rock.x, rock.y, rock.rx, rock.ry, 0, 0, Math.PI * 2)
  ctx.fillStyle = '#1c1814'
  ctx.fill()
  ctx.strokeStyle = 'rgba(232, 196, 140, 0.14)'
  ctx.stroke()
}

function drawDrop(
  ctx: CanvasRenderingContext2D,
  g: GameState,
  x: number,
  y: number,
  rarity: string,
) {
  const color = rarity === 'rare' ? '#ffd700' : rarity === 'magic' ? '#9aa4ff' : rarity === 'currency' ? '#d18bff' : '#c8c2b4'
  const pulse = g.reducedMotion ? 52 : 46 + Math.sin(g.simTime * 3 + x) * 8
  const beam = ctx.createLinearGradient(x, y - pulse, x, y)
  beam.addColorStop(0, 'rgba(0,0,0,0)')
  beam.addColorStop(1, color)
  ctx.strokeStyle = beam
  ctx.globalAlpha = 0.85
  ctx.lineWidth = 2
  ctx.beginPath()
  ctx.moveTo(x, y - pulse)
  ctx.lineTo(x, y)
  ctx.stroke()
  ctx.globalAlpha = 1
  ctx.fillStyle = color
  ctx.beginPath()
  ctx.arc(x, y, 5, 0, Math.PI * 2)
  ctx.fill()
}

function drawMonster(ctx: CanvasRenderingContext2D, monster: Monster) {
  ctx.save()
  ctx.translate(monster.x, monster.y)
  ctx.globalAlpha = monster.alive ? 1 : 0.25
  const color = monster.kind === 'hex' ? '#d2b56a' : monster.kind === 'wisp' ? '#e07a3d' : '#d3694d'
  ctx.fillStyle = monster.flash > 0 ? '#fff4e4' : color
  ctx.beginPath()
  if (monster.kind === 'hex') {
    for (let i = 0; i < 6; i++) {
      const angle = (Math.PI / 3) * i - Math.PI / 2
      const px = Math.cos(angle) * 16
      const py = Math.sin(angle) * 16
      if (i === 0) ctx.moveTo(px, py)
      else ctx.lineTo(px, py)
    }
    ctx.closePath()
  } else if (monster.kind === 'wisp') {
    ctx.moveTo(0, -18)
    ctx.lineTo(14, 12)
    ctx.lineTo(-14, 12)
    ctx.closePath()
  } else {
    ctx.arc(0, 2, 13, 0, Math.PI * 2)
  }
  ctx.fill()
  if (monster.kind === 'horn') {
    ctx.beginPath()
    ctx.moveTo(-8, -6)
    ctx.lineTo(-13, -20)
    ctx.lineTo(-1, -10)
    ctx.moveTo(8, -6)
    ctx.lineTo(13, -20)
    ctx.lineTo(1, -10)
    ctx.fill()
  }
  if (monster.alive) {
    const pct = monster.hp / monster.maxHp
    ctx.fillStyle = 'rgba(0,0,0,0.45)'
    ctx.fillRect(-16, -28, 32, 4)
    ctx.fillStyle = pct > 0.35 ? '#e8a15a' : '#e07070'
    ctx.fillRect(-16, -28, 32 * pct, 4)
  }
  ctx.restore()
}

function drawTarget(ctx: CanvasRenderingContext2D, g: GameState, x: number, y: number) {
  ctx.save()
  ctx.translate(x, y)
  if (!g.reducedMotion) ctx.rotate(g.simTime * 1.6)
  ctx.strokeStyle = '#e8a15a'
  ctx.lineWidth = 1.5
  ctx.strokeRect(-20, -20, 40, 40)
  ctx.restore()
  ctx.save()
  ctx.setLineDash([4, 7])
  ctx.strokeStyle = 'rgba(232, 161, 90, 0.45)'
  ctx.beginPath()
  ctx.moveTo(g.playerX, g.playerY)
  ctx.lineTo(x, y)
  ctx.stroke()
  ctx.setLineDash([])
  ctx.restore()
}

function drawTrail(ctx: CanvasRenderingContext2D, g: GameState) {
  const trail = g.reducedMotion ? g.trail.slice(-4) : g.trail
  trail.forEach((point, index) => {
    ctx.globalAlpha = ((index + 1) / trail.length) * 0.45
    ctx.fillStyle = '#e8a15a'
    ctx.beginPath()
    ctx.arc(point.x, point.y, 3, 0, Math.PI * 2)
    ctx.fill()
  })
  ctx.globalAlpha = 1
}

function drawPlayer(ctx: CanvasRenderingContext2D, g: GameState) {
  const glow = ctx.createRadialGradient(g.playerX, g.playerY, 2, g.playerX, g.playerY, 28)
  glow.addColorStop(0, 'rgba(255, 176, 90, 0.45)')
  glow.addColorStop(1, 'rgba(255, 176, 90, 0)')
  ctx.fillStyle = glow
  ctx.beginPath()
  ctx.arc(g.playerX, g.playerY, 28, 0, Math.PI * 2)
  ctx.fill()

  ctx.save()
  ctx.translate(g.playerX, g.playerY)
  ctx.rotate(g.facing)
  ctx.beginPath()
  ctx.moveTo(16, 0)
  ctx.lineTo(0, 9)
  ctx.lineTo(-11, 0)
  ctx.lineTo(0, -9)
  ctx.closePath()
  ctx.fillStyle = g.hurt > 0 ? '#ffb0a4' : '#f3d7b0'
  ctx.fill()
  ctx.strokeStyle = '#e8a15a'
  ctx.lineWidth = 1.5
  ctx.stroke()
  ctx.restore()
}

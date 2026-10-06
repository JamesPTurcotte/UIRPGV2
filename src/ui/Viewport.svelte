<script lang="ts">
  import { onMount } from 'svelte'
  import { game } from '../game/store.svelte'
  import { held } from '../input'
  import { queueNova, setClickTarget, step } from '../game/sim'
  import { writeSave } from '../persist'
  import { draw, resizeCanvas, screenToWorld } from '../render/viewport'

  let canvas: HTMLCanvasElement | undefined = $state()

  onMount(() => {
    if (!canvas) return
    const surface = canvas
    let frame = 0
    let last = performance.now()
    let saveAcc = 0
    let width = 0
    let height = 0
    let dpr = 1
    const tick = (now: number) => {
      const dt = Math.min(0.05, (now - last) / 1000)
      last = now
      step(game, dt, held)
      saveAcc += dt
      if (saveAcc > 2) {
        writeSave(game)
        saveAcc = 0
      }
      const rect = surface.getBoundingClientRect()
      const nextDpr = Math.min(2, window.devicePixelRatio || 1)
      if (rect.width !== width || rect.height !== height || nextDpr !== dpr) {
        const size = resizeCanvas(surface)
        width = size.width
        height = size.height
        dpr = size.dpr
      }
      const ctx = surface.getContext('2d')
      if (ctx && width > 0 && height > 0) draw(ctx, width, height, dpr, game)
      frame = requestAnimationFrame(tick)
    }
    frame = requestAnimationFrame(tick)
    return () => cancelAnimationFrame(frame)
  })

  function pointer(event: PointerEvent) {
    if (!canvas) return
    if (event.button === 2) {
      queueNova(game)
      return
    }
    if (event.button !== 0) return
    const rect = canvas.getBoundingClientRect()
    const world = screenToWorld(event.clientX - rect.left, event.clientY - rect.top)
    setClickTarget(game, world.x, world.y)
  }
</script>

<div class="viewport">
  <canvas
    bind:this={canvas}
    data-testid="viewport"
    aria-label="Battle view"
    onpointerdown={pointer}
    oncontextmenu={(event) => event.preventDefault()}
  ></canvas>
</div>

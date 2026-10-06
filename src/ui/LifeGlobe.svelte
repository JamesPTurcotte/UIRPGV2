<script lang="ts">
  import { game } from '../game/store.svelte'
  import { derive } from '../game/items'

  let { size = 108, gid = 'hud', sheet = false }: { size?: number; gid?: string; sheet?: boolean } = $props()
  let stats = $derived(derive(game))
  let pct = $derived(stats.maxLife <= 0 ? 0 : Math.max(0, Math.min(1, game.life / stats.maxLife)))
  let y = $derived(100 - pct * 84)
</script>

<div class="globe-wrap" class:sheet class:low={pct < 0.3} style="width: {size}px">
  <svg viewBox="0 0 100 100" role="img" aria-label="Life {Math.round(game.life)} of {stats.maxLife}">
    <defs>
      <clipPath id="{gid}-clip"><circle cx="50" cy="50" r="40" /></clipPath>
    </defs>
    <circle cx="50" cy="50" r="46" fill="#140e0c" stroke="rgba(232,196,140,0.4)" stroke-width="2" />
    <g clip-path="url(#{gid}-clip)">
      <rect x="0" y={y} width="100" height="100" fill="#8d2424" />
      <rect x="0" y={y} width="100" height="18" fill="#c4473a" opacity="0.85" />
    </g>
    <text x="50" y="54" text-anchor="middle" fill="#f6efe6" font-size="16" font-family="Source Sans 3, sans-serif">
      {Math.ceil(game.life)}
    </text>
  </svg>
  <p>{Math.ceil(game.life)} / {stats.maxLife}</p>
</div>

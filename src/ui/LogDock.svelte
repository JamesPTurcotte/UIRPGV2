<script lang="ts">
  import { game } from '../game/store.svelte'
  import { dpsBuckets, rollingDps } from '../game/combat'

  let series = $derived(dpsBuckets(game.damageEvents, game.simTime))
  let dps = $derived(rollingDps(game.damageEvents, game.simTime))
  let path = $derived.by(() => {
    const max = Math.max(1, ...series)
    return series
      .map((value, index) => {
        const x = (index / Math.max(1, series.length - 1)) * 240
        const y = 62 - (value / max) * 56
        return `${index === 0 ? 'M' : 'L'}${x.toFixed(1)} ${y.toFixed(1)}`
      })
      .join(' ')
  })
</script>

<aside class="dock" aria-label="Combat">
  <section class="card">
    <p class="dps" data-testid="dps">{dps.toFixed(1)} <span>dps</span></p>
    <svg class="spark" viewBox="0 0 240 64" aria-hidden="true">
      <path d={path} />
    </svg>
  </section>
  <section class="card log-card">
    <h2>Log</h2>
    {#if game.log.length === 0}
      <p class="empty">The fight will write itself here.</p>
    {:else}
      <ul class="log">
        {#each game.log as line (line.id)}
          <li class={line.tone}>{line.text}</li>
        {/each}
      </ul>
    {/if}
  </section>
</aside>

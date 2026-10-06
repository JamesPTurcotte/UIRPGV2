<script lang="ts">
  import { game } from '../game/store.svelte'
  import { baseOf, compare, formatImplicit, statLabel } from '../game/items'
  import { formatDelta } from '../game/combat'
  import { findItem } from '../game/sim'

  let item = $derived(game.hoverId ? findItem(game, game.hoverId) : undefined)
  let base = $derived(item ? baseOf(item.baseId) : undefined)
  let deltas = $derived(item ? compare(game, item) : [])
  let equipped = $derived(item ? game.equipped[item.slot]?.id === item.id : false)
  let left = $derived.by(() => {
    if (!item || typeof window === 'undefined') return game.hoverX + 16
    return game.hoverX + 280 > window.innerWidth ? game.hoverX - 276 : game.hoverX + 16
  })
  let top = $derived.by(() => {
    if (!item || typeof window === 'undefined') return game.hoverY + 16
    return game.hoverY + 240 > window.innerHeight ? Math.max(8, game.hoverY - 220) : game.hoverY + 16
  })
</script>

{#if item && base}
  <div class="tip" style="left: {left}px; top: {top}px">
    <p class="rarity {item.rarity}">{item.rarity}</p>
    <h3 class={item.rarity}>{item.name}</h3>
    <p class="muted">{base.name} · {item.slot}</p>
    <p>{formatImplicit(base.implicit.stat, base.implicit.value)}</p>
    {#if item.affixes.length}
      <ul class="affixes">
        {#each item.affixes as affix (`${affix.id}-${affix.value}`)}
          <li><span>{affix.name}</span><b>{formatDelta(affix.stat, affix.value)}</b></li>
        {/each}
      </ul>
    {/if}
    {#if equipped}
      <p class="muted">Equipped</p>
    {:else if deltas.length}
      <p class="muted">Against what you wear</p>
      <ul class="deltas">
        {#each deltas as row (row.stat)}
          <li class:good={row.delta > 0} class:bad={row.delta < 0}>
            <span>{statLabel(row.stat)}</span>
            <b>{formatDelta(row.stat, row.delta)}</b>
          </li>
        {/each}
      </ul>
    {:else}
      <p class="muted">No change to your stats.</p>
    {/if}
  </div>
{/if}

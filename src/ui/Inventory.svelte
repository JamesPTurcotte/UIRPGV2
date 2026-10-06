<script lang="ts">
  import { game } from '../game/store.svelte'
  import { INVENTORY_SLOTS } from '../game/combat'
  import { equip, setHover } from '../game/sim'
  import type { Item } from '../game/types'

  let cells = $derived.by(() => {
    const next: (Item | null)[] = Array.from({ length: INVENTORY_SLOTS }, () => null)
    game.inventory.forEach((item, index) => {
      if (index < INVENTORY_SLOTS) next[index] = item
    })
    return next
  })

  function hover(id: string, event: MouseEvent) {
    setHover(game, id, event.clientX, event.clientY)
  }
</script>

<section class="panel" aria-label="Inventory">
  <header>
    <h2>Inventory</h2>
    <p class="muted">Click a piece to equip it.</p>
  </header>
  <div class="bag">
    {#each cells as item, index (item?.id ?? `empty-${index}`)}
      {#if item}
        <button
          class="slot {item.rarity}"
          onmouseenter={(event) => hover(item.id, event)}
          onmousemove={(event) => hover(item.id, event)}
          onmouseleave={() => setHover(game, null)}
          onclick={() => equip(game, item.id)}
        >
          <small>{item.slot}</small>
          <b>{item.name}</b>
        </button>
      {:else}
        <div class="slot empty"></div>
      {/if}
    {/each}
  </div>
</section>

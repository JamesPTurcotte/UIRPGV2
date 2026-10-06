<script lang="ts">
  import { game } from '../game/store.svelte'
  import { formatDelta } from '../game/combat'
  import { canReroll, canUpgrade } from '../game/craft'
  import { selectCraft, setHover, useReroll, useUpgrade } from '../game/sim'

  let selected = $derived(game.inventory.find((item) => item.id === game.craftId) ?? null)
  let upgradeReason = $derived.by(() => {
    if (game.upgradeOrbs <= 0) return 'No Kindling.'
    if (!selected) return 'Choose an item.'
    if (!canUpgrade(selected)) return 'Kindling only lifts a normal item.'
    return ''
  })
  let rerollReason = $derived.by(() => {
    if (game.rerollOrbs <= 0) return 'No Ash Salt.'
    if (!selected) return 'Choose an item.'
    if (!canReroll(selected)) return 'Ash Salt only rerolls a rare.'
    return ''
  })
</script>

<section class="panel" aria-label="Craft">
  <header class="craft-head">
    <h2>Craft</h2>
    <p class="muted">Salt {game.rerollOrbs} · Kindling {game.upgradeOrbs}</p>
  </header>
  <p class="muted">Drops wait in the bag. Kindling lifts a normal into magic. Ash Salt rerolls a rare. Nothing here equips itself.</p>
  <div class="craft-grid">
    <div class="bag">
      {#each game.inventory as item (item.id)}
        <button
          class="slot {item.rarity}"
          class:selected={item.id === game.craftId}
          onmouseenter={(event) => setHover(game, item.id, event.clientX, event.clientY)}
          onmousemove={(event) => setHover(game, item.id, event.clientX, event.clientY)}
          onmouseleave={() => setHover(game, null)}
          onclick={() => selectCraft(game, item.id)}
        >
          <small>{item.rarity}</small>
          <b>{item.name}</b>
        </button>
      {:else}
        <p class="empty">The bag is empty.</p>
      {/each}
    </div>
    <div>
      {#if selected}
        <h3 class={selected.rarity}>{selected.name}</h3>
        <ul class="affixes">
          {#each selected.affixes as affix (`${affix.id}-${affix.value}`)}
            <li><span>{affix.name}</span><b>{formatDelta(affix.stat, affix.value)}</b></li>
          {:else}
            <li><span>No affixes yet.</span></li>
          {/each}
        </ul>
      {:else}
        <p class="empty">Select something from the bag.</p>
      {/if}
      <div class="actions">
        <button disabled={Boolean(upgradeReason)} onclick={() => selected && useUpgrade(game, selected.id)}>
          Use Kindling
        </button>
        <button disabled={Boolean(rerollReason)} onclick={() => selected && useReroll(game, selected.id)}>
          Use Ash Salt
        </button>
        <p class="hint">{upgradeReason || rerollReason}</p>
      </div>
    </div>
  </div>
</section>

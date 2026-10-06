<script lang="ts">
  import { game } from '../game/store.svelte'
  import { MAPS, isUnlocked } from '../game/atlas'
  import { openMap } from '../game/sim'
</script>

<section class="panel" aria-label="Atlas">
  <header>
    <h2>Atlas</h2>
    <p class="muted">{game.auto ? 'Auto is choosing the maps.' : 'Open the next map from the hideout.'}</p>
  </header>
  <div class="atlas-list">
    {#each MAPS as map (map.id)}
      {@const unlocked = isUnlocked(map.id, game.cleared)}
      <article class="atlas-card" class:locked={!unlocked} class:cleared={game.cleared[map.id]}>
        <h3>{map.name}</h3>
        <p class="muted">{map.blurb}</p>
        {#if game.cleared[map.id]}
          <p>Cleared</p>
        {:else if !unlocked}
          <p>Locked</p>
        {:else if game.auto}
          <p>Auto will walk in.</p>
        {:else if game.phase !== 'hideout'}
          <p>Return to the hideout to open it.</p>
        {:else}
          <button onclick={() => openMap(game, map.id)}>Open</button>
        {/if}
      </article>
    {/each}
  </div>
</section>

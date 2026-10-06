<script lang="ts">
  import { game } from '../game/store.svelte'
  import { PASSIVES, canAllocate } from '../game/passives'
  import { allocate, refundPassives } from '../game/sim'

  function tone(id: string): string {
    if (game.allocated.includes(id)) return '#e8a15a'
    if (canAllocate(id, game.allocated, game.passivePoints)) return '#f3d7b0'
    return '#5c564e'
  }
</script>

<section class="panel" aria-label="Passives">
  <header>
    <h2>Passives</h2>
    <p class="muted">{game.passivePoints} unspent</p>
  </header>
  <div class="passive-grid">
    <svg class="constellation" viewBox="0 0 100 100" role="img" aria-label="Passive constellation">
      <circle cx="50" cy="52" r="3" fill="#e8a15a" />
      {#each PASSIVES as node (node.id)}
        {@const parent = PASSIVES.find((entry) => entry.id === node.requires)}
        <line
          x1={parent ? parent.x : 50}
          y1={parent ? parent.y : 52}
          x2={node.x}
          y2={node.y}
          stroke="rgba(232,196,140,0.35)"
          stroke-width="0.6"
        />
      {/each}
      {#each PASSIVES as node (node.id)}
        <circle cx={node.x} cy={node.y} r="3.2" fill={tone(node.id)} />
      {/each}
    </svg>
    <div>
      <div class="node-list">
        {#each PASSIVES as node (node.id)}
          <button
            class:have={game.allocated.includes(node.id)}
            disabled={!canAllocate(node.id, game.allocated, game.passivePoints) && !game.allocated.includes(node.id)}
            onclick={() => allocate(game, node.id)}
          >
            <strong>{node.name}</strong>
            <span class="muted"> {node.text}</span>
          </button>
        {/each}
      </div>
      <div class="actions">
        <button disabled={game.phase !== 'hideout' || game.allocated.length === 0} onclick={() => refundPassives(game)}>
          Refund in hideout
        </button>
        {#if game.phase !== 'hideout'}
          <p class="hint">Leave the map before you refund.</p>
        {/if}
      </div>
    </div>
  </div>
</section>

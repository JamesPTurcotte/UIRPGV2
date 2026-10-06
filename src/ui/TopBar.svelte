<script lang="ts">
  import { game } from '../game/store.svelte'
  import { mapById } from '../game/atlas'
  import { leaveMap, toggleAuto, togglePanel } from '../game/sim'

  let zone = $derived(game.phase === 'hideout' ? 'Hideout' : mapById(game.mapId)?.name ?? 'Atlas')
  let map = $derived(mapById(game.mapId))
</script>

<header class="topbar">
  <div class="brand">
    <strong>UIRPG</strong>
    <span>{zone}</span>
    {#if map && game.phase === 'map'}
      <span class="chip">{map.blurb}</span>
    {/if}
  </div>
  <div class="top-actions">
    <span class="orb" title="Rerolls a rare">Salt <b>{game.rerollOrbs}</b></span>
    <span class="orb" title="Lifts a normal item into magic">Kindling <b>{game.upgradeOrbs}</b></span>
    <span class="level">Lv {game.level}</span>
    {#if game.passivePoints > 0}
      <button class="ghost alert" onclick={() => togglePanel(game, 'passives')}>
        {game.passivePoints} unspent
      </button>
    {/if}
    {#if game.phase === 'map' && !game.auto}
      <button class="ghost" onclick={() => leaveMap(game)}>Hideout</button>
    {/if}
    <button
      class="auto"
      class:on={game.auto}
      aria-pressed={game.auto}
      aria-keyshortcuts="F"
      data-testid="auto"
      onclick={() => toggleAuto(game)}
    >
      <span class="thumb"></span>
      <span>{game.auto ? 'Auto' : 'Manual'}</span>
    </button>
  </div>
</header>

<script lang="ts">
  import { game } from '../game/store.svelte'
  import { derive } from '../game/items'
  import { xpToNext } from '../game/combat'
  import { setHover, unequip } from '../game/sim'
  import type { Slot } from '../game/types'
  import LifeGlobe from './LifeGlobe.svelte'

  let stats = $derived(derive(game))
  let need = $derived(xpToNext(game.level))
  let xpPct = $derived(Math.min(100, (game.xp / need) * 100))
  const slots: Slot[] = ['weapon', 'armor', 'ring']

  function hover(id: string | undefined, event: MouseEvent) {
    setHover(game, id ?? null, event.clientX, event.clientY)
  }
</script>

<section class="panel" aria-label="Character">
  <header>
    <h2>Character</h2>
    <p class="muted">Level {game.level}</p>
  </header>
  <div class="sheet-grid">
    <LifeGlobe size={132} gid="sheet" sheet />
    <ul class="stats">
      <li><span>Damage</span><b>{stats.damage}</b></li>
      <li><span>Attack speed</span><b>{stats.attackSpeed.toFixed(2)}/s</b></li>
      <li><span>Crit</span><b>{Math.round(stats.crit * 100)}%</b></li>
      <li><span>Fire res</span><b>{Math.round(stats.fireRes)}%</b></li>
    </ul>
    <div class="doll">
      {#each slots as slot (slot)}
        {@const item = game.equipped[slot]}
        {#if item}
          <button
            class="slot {item.rarity}"
            onmouseenter={(event) => hover(item.id, event)}
            onmousemove={(event) => hover(item.id, event)}
            onmouseleave={() => setHover(game, null)}
            onclick={() => unequip(game, slot)}
          >
            <small>{slot}</small>
            <b>{item.name}</b>
          </button>
        {:else}
          <div class="slot empty"><small>{slot}</small><b>Empty</b></div>
        {/if}
      {/each}
    </div>
  </div>
  <div class="xp" aria-hidden="true"><span style="width: {xpPct}%"></span></div>
  <p class="muted">{Math.floor(game.xp)} / {need} experience</p>
</section>

<script lang="ts">
  import { game } from '../game/store.svelte'
  import { NOVA_CD } from '../game/combat'
  import { queueNova } from '../game/sim'

  let ready = $derived(game.novaTimer <= 0)
  let cover = $derived(Math.max(0, Math.min(1, game.novaTimer / NOVA_CD)))
</script>

<div class="skillbar" aria-label="Skills">
  <button class="skill" class:ready data-testid="nova" onclick={() => queueNova(game)} aria-keyshortcuts="Q">
    <span class="cd" style="height: {cover * 100}%"></span>
    <strong>Nova</strong>
  </button>
  {#each [1, 2, 3] as slot (slot)}
    <div class="skill" aria-hidden="true"><em>Empty</em></div>
  {/each}
</div>

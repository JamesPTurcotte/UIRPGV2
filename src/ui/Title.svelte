<script lang="ts">
  import { game } from '../game/store.svelte'
  import { begin } from '../game/sim'
</script>

<div class="title">
  <div>
    <p class="eyebrow">A code-drawn atlas</p>
    <h1>UIRPG</h1>
    <p class="lede">The character walks the maps. You keep the gear, the craft, and the points.</p>
    <button class="enter" data-testid="enter" onclick={() => begin(game)}>Enter</button>
    <p class="hint">
      {game.auto
        ? 'Auto is on. Press F anytime to take the controls.'
        : 'Manual control is saved. Press F to let the character play.'}
    </p>
  </div>
</div>

<script lang="ts">
  import { game } from '../game/store.svelte'
  let { ondismiss }: { ondismiss: () => void } = $props()
</script>

<div class="summary">
  <h2>{game.summary}</h2>
  {#if !game.auto}
    <p>Auto is off. Gear up, then turn it back on.</p>
  {/if}
  <button onclick={ondismiss}>Continue</button>
</div>

<script lang="ts">
  import { game } from '../game/store.svelte'
  import { togglePanel } from '../game/sim'
  import type { PanelId } from '../game/types'

  const buttons: { id: PanelId; label: string; key: string }[] = [
    { id: 'character', label: 'Character', key: 'C' },
    { id: 'inventory', label: 'Inventory', key: 'I' },
    { id: 'craft', label: 'Craft', key: 'K' },
    { id: 'atlas', label: 'Atlas', key: 'G' },
    { id: 'passives', label: 'Passives', key: 'P' },
  ]
</script>

<nav class="rail" aria-label="Panels">
  {#each buttons as button (button.id)}
    <button
      class:active={game.panel === button.id}
      aria-label="{button.label} ({button.key})"
      aria-keyshortcuts={button.key}
      onclick={() => togglePanel(game, button.id)}
    >
      {#if button.id === 'character'}
        <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="1.6"><circle cx="12" cy="8" r="3"/><path d="M5 19c1.5-3 3.8-4.5 7-4.5S17.5 16 19 19"/></svg>
      {:else if button.id === 'inventory'}
        <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="1.6"><rect x="4" y="4" width="7" height="7" rx="1"/><rect x="13" y="4" width="7" height="7" rx="1"/><rect x="4" y="13" width="7" height="7" rx="1"/><rect x="13" y="13" width="7" height="7" rx="1"/></svg>
      {:else if button.id === 'craft'}
        <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="1.6"><path d="M12 3l2.2 5.2L20 10l-4.2 3.2L17 19l-5-3-5 3 1.2-5.8L4 10l5.8-1.8z"/></svg>
      {:else if button.id === 'atlas'}
        <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="1.6"><circle cx="6" cy="16" r="2"/><circle cx="12" cy="8" r="2"/><circle cx="18" cy="15" r="2"/><path d="M8 15l3-5 4 5"/></svg>
      {:else}
        <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="1.6"><circle cx="12" cy="12" r="2"/><circle cx="6" cy="7" r="1.4"/><circle cx="18" cy="7" r="1.4"/><circle cx="7" cy="17" r="1.4"/><circle cx="17" cy="17" r="1.4"/><path d="M7.2 8.2L10.4 11M16.8 8.2L13.6 11M8.2 16.2l2.4-2.8M15.8 16.2l-2.4-2.8"/></svg>
      {/if}
      <span class="lbl">{button.label} ({button.key})</span>
      {#if button.id === 'passives' && game.passivePoints > 0}
        <i class="dot"></i>
      {/if}
    </button>
  {/each}
</nav>

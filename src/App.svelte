<script lang="ts">
  import { onMount } from 'svelte'
  import { game } from './game/store.svelte'
  import { held, isMoveKey, nudgeKey } from './input'
  import { begin, closePanel, dismissSummary, queueNova, toggleAuto, togglePanel } from './game/sim'
  import { writeSave } from './persist'
  import Title from './ui/Title.svelte'
  import TopBar from './ui/TopBar.svelte'
  import Rail from './ui/Rail.svelte'
  import Viewport from './ui/Viewport.svelte'
  import LifeGlobe from './ui/LifeGlobe.svelte'
  import SkillBar from './ui/SkillBar.svelte'
  import LogDock from './ui/LogDock.svelte'
  import Sheet from './ui/Sheet.svelte'
  import Inventory from './ui/Inventory.svelte'
  import Craft from './ui/Craft.svelte'
  import Atlas from './ui/Atlas.svelte'
  import Passives from './ui/Passives.svelte'
  import Tooltip from './ui/Tooltip.svelte'
  import Summary from './ui/Summary.svelte'

  onMount(() => {
    const down = (event: KeyboardEvent) => {
      const key = event.key.toLowerCase()
      if (isMoveKey(key)) {
        event.preventDefault()
        held.add(key)
        if (!event.repeat) nudgeKey(key)
      }
      if (event.repeat) return
      if (game.phase === 'title') {
        if (key === 'enter') begin(game)
        return
      }
      if (key === 'f') toggleAuto(game)
      else if (key === 'i') togglePanel(game, 'inventory')
      else if (key === 'c') togglePanel(game, 'character')
      else if (key === 'k') togglePanel(game, 'craft')
      else if (key === 'g') togglePanel(game, 'atlas')
      else if (key === 'p') togglePanel(game, 'passives')
      else if (key === 'escape') closePanel(game)
      else if (key === 'q') queueNova(game)
    }
    const up = (event: KeyboardEvent) => {
      held.delete(event.key.toLowerCase())
    }
    const blur = () => held.clear()
    const leave = () => writeSave(game)
    window.addEventListener('keydown', down)
    window.addEventListener('keyup', up)
    window.addEventListener('blur', blur)
    window.addEventListener('beforeunload', leave)
    return () => {
      writeSave(game)
      window.removeEventListener('keydown', down)
      window.removeEventListener('keyup', up)
      window.removeEventListener('blur', blur)
      window.removeEventListener('beforeunload', leave)
    }
  })
</script>

{#if game.phase === 'title'}
  <Title />
{:else}
  <div class="app">
    <TopBar />
    <div class="stage">
      <Viewport />
      <Rail />
      <LifeGlobe />
      <LogDock />
      <SkillBar />
      {#if game.banner && (game.bannerLife > 0 || game.resolving)}
        <div class="banner" aria-live="polite">{game.banner}</div>
      {/if}
      {#if game.summary}
        <Summary ondismiss={() => dismissSummary(game)} />
      {/if}
      {#if game.panel === 'character'}
        <Sheet />
      {:else if game.panel === 'inventory'}
        <Inventory />
      {:else if game.panel === 'craft'}
        <Craft />
      {:else if game.panel === 'atlas'}
        <Atlas />
      {:else if game.panel === 'passives'}
        <Passives />
      {/if}
      <Tooltip />
    </div>
  </div>
{/if}

import { svelte } from '@sveltejs/vite-plugin-svelte'
import { defineConfig } from 'vitest/config'

export default defineConfig(({ command }) => ({
  plugins: [svelte()],
  // Project pages are served from /UIRPGV2/. The dev server stays at /.
  base: command === 'build' ? '/UIRPGV2/' : '/',
  test: {
    environment: 'node',
    include: ['src/**/*.test.ts'],
  },
}))

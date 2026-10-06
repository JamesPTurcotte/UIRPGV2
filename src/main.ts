import { mount } from 'svelte'
import App from './App.svelte'
import './app.css'
import '@fontsource/fraunces/400.css'
import '@fontsource/fraunces/600.css'
import '@fontsource/source-sans-3/400.css'
import '@fontsource/source-sans-3/600.css'

const target = document.getElementById('app')
if (!target) throw new Error('Missing #app')
mount(App, { target })

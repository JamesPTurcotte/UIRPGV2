import { freshState } from './state'
import { applySave, readSave } from '../persist'

export const game = $state(freshState())

const saved = readSave()
if (saved) applySave(game, saved)

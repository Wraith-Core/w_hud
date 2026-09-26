/* ════════════════════════════════════════════════════════════════════════════
 * w_hud · settings/states.ts
 * Which colour a circle takes right now -- one answer, from every state it is in.
 *
 * ★ A state is the circle itself changing colour, never a shape added to it. So a circle shows
 *   exactly one look at a time, and when it is in two states at once (poisoned and in danger, a
 *   booster on a stamina core that is low) one of them has to win. The order is decided here, in
 *   one small function, rather than by which CSS rule happens to carry !important.
 *
 *   dangerWins (stock)   danger > poison > booster > warning > normal
 *   !dangerWins          poison > booster > danger > warning > normal
 *
 * ★ Why danger first by default: the red says "you are about to die", and that is the one you act
 *   on; the poison and the booster colours say what is happening to you, and they come back the
 *   moment the core climbs out of danger. A player who would rather keep seeing the poison while
 *   it lasts turns the switch off (Colours -> "لون الخطر يعلو على السمّ والمعزِّز").
 *
 * ★ Poison before a booster: the poison is the one that hurts and has a cure to go and find.
 * ★ Both before the warning: the warning is the core running down, the everyday state; a poison or
 *   a booster is news.
 * ════════════════════════════════════════════════════════════════════════════ */

import type { ThemeKey } from './types';

/** How far a gauge has run down -- from its value and the warning lines. */
export type CoreLevel = 'ok' | 'warn' | 'danger';

/** What the circle is painted as: its level, or the state that outranks it. One CSS class each (hud.css). */
export type CoreLook = CoreLevel | 'poison' | 'boost-health' | 'boost-stamina';

export interface CoreMarks {
  /** Poisoned: only the player's health core carries it. */
  poison?: boolean;
  /** A booster on this core: 'health' for a health core, 'stamina' for a stamina core. */
  boost?: 'health' | 'stamina' | null;
}

export function coreLook(level: CoreLevel, marks: CoreMarks = {}, dangerWins = true): CoreLook {
  if (level === 'danger' && dangerWins) return 'danger';
  if (marks.poison) return 'poison';
  if (marks.boost) return marks.boost === 'health' ? 'boost-health' : 'boost-stamina';
  return level;
}

/**
 * The Colours pane's live preview: while a state field is hovered or its chooser is open, the
 * circles that state belongs to are shown in it, so the colour is picked while looking at it (a
 * poison or a booster is otherwise nowhere to be seen when you want it).
 * Returns the look to force on circle `core`, or null to leave it as it is.
 */
export type CoreKind = 'health' | 'stamina' | 'horseHealth' | 'horseStamina' | 'need' | 'voice';

export function previewLook(field: ThemeKey | null, core: CoreKind): CoreLook | null {
  switch (field) {
    case 'warn': return core === 'voice' ? null : 'warn';
    case 'danger': return core === 'voice' ? null : 'danger';
    case 'poison': return core === 'health' ? 'poison' : null;
    case 'boostHealth': return core === 'health' || core === 'horseHealth' ? 'boost-health' : null;
    case 'boostStamina': return core === 'stamina' || core === 'horseStamina' ? 'boost-stamina' : null;
    default: return null;
  }
}

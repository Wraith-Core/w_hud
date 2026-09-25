/* ════════════════════════════════════════════════════════════════════════════
 * w_hud · settings/theme.ts
 * Turning six chosen colours into the variables hud.css already speaks.
 *
 * ★ The HUD was written against a small set of variables long before it was
 *   configurable -- --gold-1/2/3, --cream, --dim, --line, --warn, --danger,
 *   --poison. So the panel changes **those** and touches no rule: nothing in the
 *   stylesheet knows a settings panel exists, and a colour applied here reaches
 *   every element that was ever drawn with it, including ones added later.
 *
 * ★ Every colour is written twice -- once whole and once as bare channels. Glows,
 *   fills and tracks are all the same hue at different alphas, and rgba() cannot take
 *   a hex; `rgba(var(--danger-rgb), 0.9)` can. That pair is what lets one chosen red
 *   reach a dozen different strengths of itself.
 *
 * ⚠️ Written on the document element, not on .hud-root: the weapon wheel and the
 *   settings panel live outside that container and must follow the same palette.
 * ════════════════════════════════════════════════════════════════════════════ */

import { hexToRgb, rgba } from './color';
import { INK, darker, lighter, toTone } from './palette';
import type { ShapeCfg, Theme } from './types';

/** "229, 45, 45" -- the form rgba() can take through a variable. */
const channels = (hex: string): string => {
  const { r, g, b } = hexToRgb(hex);
  return `${Math.round(r)}, ${Math.round(g)}, ${Math.round(b)}`;
};

/**
 * The palette the HUD is drawn in: every chosen colour as the ink/paper tone nearest to it,
 * and the danger colour as the theme's one red when it is a red at all (palette.ts).
 *
 * ⚠️ The saved theme is not touched -- a blue accent from an older build stays in the save
 *   and is drawn as paper. Clamping here, at the paint, is what keeps saved data intact.
 */
export function drawnTheme(theme: Theme): Theme {
  return {
    accent: toTone(theme.accent),
    text: toTone(theme.text),
    dim: toTone(theme.dim),
    warn: toTone(theme.warn),
    danger: toTone(theme.danger, { red: true }),
    poison: toTone(theme.poison),
  };
}

export function applyTheme(saved: Theme): void {
  if (typeof document === 'undefined') return;

  const root = document.documentElement.style;
  const theme = drawnTheme(saved);

  /* ── the accent ramp ──────────────────────────────────────────────────────
     One tone and the two below it on the palette (paper -> paper-dim -> paper-faint),
     so a chosen accent lands on a ramp of the same shape and never off the palette. */
  root.setProperty('--gold-1', theme.accent);
  root.setProperty('--gold-2', darker(theme.accent, 1));
  root.setProperty('--gold-3', darker(theme.accent, 2));

  root.setProperty('--cream', theme.text);
  root.setProperty('--dim', theme.dim);
  root.setProperty('--line', rgba(theme.text, 0.28));

  root.setProperty('--warn', theme.warn);
  root.setProperty('--warn-rgb', channels(theme.warn));

  root.setProperty('--danger', theme.danger);
  /* The icon's face at danger. It used to be a second, brighter red derived from this one;
     the theme has one red, so the icon and its ring share it and the pulse keeps them apart. */
  root.setProperty('--danger-lit', theme.danger);
  root.setProperty('--danger-rgb', channels(theme.danger));

  /* Poison is told by its fumes and its throb, not by a hue: the ring takes the chosen tone,
     the lit heart and the smoke the tone above it, the track stays ink. */
  root.setProperty('--poison', theme.poison);
  root.setProperty('--poison-rgb', channels(theme.poison));
  root.setProperty('--poison-lit-rgb', channels(lighter(theme.poison, 1)));
  root.setProperty('--poison-deep-rgb', channels(darker(theme.poison, 2)));
  root.setProperty('--poison-track', rgba(INK, 0.75));

}

/* ════════════════════════════════════════════════════════════════════════════
 * The shape of the circles
 *
 * ★ Variables again rather than props. The circle is drawn by six rules in hud.css and
 *   an SVG in App.tsx; threading four numbers through both would mean touching every
 *   one of them and every future one. Set here, read there, and a circle added next
 *   month inherits the player's choice without knowing this file exists.
 *
 * ⚠️ `motion` is a class, not a variable: switching animations off is a blanket rule
 *   over rules that live in a dozen places (heartbeat, warnPulse, gildBreathe,
 *   poisonFume, wvPulse), and there is no variable that reaches all of them.
 * ════════════════════════════════════════════════════════════════════════════ */
export function applyShape(shape: ShapeCfg): void {
  if (typeof document === 'undefined') return;

  const root = document.documentElement.style;

  root.setProperty('--core-ring-w', String(shape.ring));
  root.setProperty('--core-disc-a', String(shape.disc));
  root.setProperty('--core-ic-size', `${shape.icon * 100}%`);

  document.documentElement.classList.toggle('no-motion', !shape.motion);
}

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

import { hexToRgb, rgba, shade } from './color';
import type { ShapeCfg, Theme } from './types';

/** "229, 45, 45" -- the form rgba() can take through a variable. */
const channels = (hex: string): string => {
  const { r, g, b } = hexToRgb(hex);
  return `${Math.round(r)}, ${Math.round(g)}, ${Math.round(b)}`;
};

export function applyTheme(theme: Theme): void {
  if (typeof document === 'undefined') return;

  const root = document.documentElement.style;

  /* ── the accent ramp ──────────────────────────────────────────────────────
     One colour at three brightnesses -- the same relationship the stock palette
     had (#FFFFFF / #DCDCDC / #8C8C8C), so a chosen accent lands on a ramp of the
     same shape rather than three unrelated values. */
  root.setProperty('--gold-1', theme.accent);
  root.setProperty('--gold-2', shade(theme.accent, -0.14));
  root.setProperty('--gold-3', shade(theme.accent, -0.45));

  root.setProperty('--cream', theme.text);
  root.setProperty('--dim', theme.dim);
  root.setProperty('--line', rgba(theme.text, 0.28));

  root.setProperty('--warn', theme.warn);
  root.setProperty('--warn-rgb', channels(theme.warn));

  root.setProperty('--danger', theme.danger);
  /* ★ The lit face of the danger colour -- the icon burns a shade brighter than its
     ring so the two layers stay apart at a glance. It used to be a second hard-coded
     red (#F04444 beside #E52D2D); deriving it keeps that relationship whatever red
     the player picks -- or whatever colour, if they pick something else entirely. */
  root.setProperty('--danger-lit', shade(theme.danger, 0.18));
  root.setProperty('--danger-rgb', channels(theme.danger));

  root.setProperty('--poison', theme.poison);
  root.setProperty('--poison-rgb', channels(theme.poison));
  root.setProperty('--poison-lit-rgb', channels(shade(theme.poison, 0.22)));
  root.setProperty('--poison-deep-rgb', channels(shade(theme.poison, -0.4)));
  root.setProperty('--poison-track', rgba(shade(theme.poison, -0.72), 0.75));

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

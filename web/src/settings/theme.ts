/* ════════════════════════════════════════════════════════════════════════════
 * w_hud · settings/theme.ts
 * Turning the chosen colours into the variables hud.css already speaks.
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
 * ★ Painted exactly as chosen, every one (since SETTINGS_VERSION 5). There is no clamp here any
 *   more: what an older save held is read as the tone it was drawn in when it is loaded
 *   (types.ts, FREE_ALL_SINCE), so it looks as it did, and anything picked since is the player's.
 *
 * ⚠️ Written on the document element, not on .hud-root: the weapon wheel lives outside that
 *   container and follows the same palette. (The settings panel does not: it keeps the theme's
 *   own paper and ink so it stays readable whatever the HUD is painted in -- settings.css.)
 * ════════════════════════════════════════════════════════════════════════════ */

import { hexToRgb, mix, normHex, readableInk, rgba } from './color';
import { INK, TONES, darker } from './palette';
import { DEFAULT_THEME, THEME_FIELDS, type ShapeCfg, type Theme } from './types';

/** "229, 45, 45" -- the form rgba() can take through a variable. */
const channels = (hex: string): string => {
  const { r, g, b } = hexToRgb(hex);
  return `${Math.round(r)}, ${Math.round(g)}, ${Math.round(b)}`;
};

/**
 * The palette the HUD is drawn in: every colour exactly as chosen, cleaned to #RRGGBB. The fields
 * that may be none chosen (money and its rows) stay '' when they are.
 */
export function drawnTheme(theme: Theme): Theme {
  const out = { ...DEFAULT_THEME };
  for (const field of THEME_FIELDS) {
    const value = theme[field.key];
    out[field.key] = field.empty
      ? (value ? normHex(value, '') : '')
      : normHex(value, DEFAULT_THEME[field.key]);
  }
  return out;
}

/**
 * The accent and the two shades under it (--gold-1/2/3).
 * ★ A tone steps down the theme's own ramp (paper -> paper-dim -> paper-faint), exactly as it always
 *   did; any other colour darkens toward ink by the same feel, so a gold accent gets a gold ramp.
 */
function ramp(accent: string, steps: 1 | 2): string {
  if ((TONES as readonly string[]).includes(accent)) return darker(accent, steps);
  return mix(accent, INK, steps === 1 ? 0.3 : 0.55);
}

/** A colour, or none: '' removes the variable so hud.css falls back to what is written beside it. */
function setOrClear(root: CSSStyleDeclaration, name: string, value: string): void {
  if (value) root.setProperty(name, value);
  else root.removeProperty(name);
}

export function applyTheme(saved: Theme): void {
  if (typeof document === 'undefined') return;

  const root = document.documentElement.style;
  const theme = drawnTheme(saved);

  root.setProperty('--gold-1', theme.accent);
  root.setProperty('--gold-2', ramp(theme.accent, 1));
  root.setProperty('--gold-3', ramp(theme.accent, 2));

  root.setProperty('--cream', theme.text);
  root.setProperty('--dim', theme.dim);
  root.setProperty('--line', rgba(theme.text, 0.28));

  /* The circles' own colour: ring, icon, and the faint copy of the icon that shows what drained. */
  root.setProperty('--core', theme.core);
  root.setProperty('--core-rgb', channels(theme.core));

  root.setProperty('--warn', theme.warn);
  root.setProperty('--warn-rgb', channels(theme.warn));

  root.setProperty('--danger', theme.danger);
  /* The icon's face at danger. It used to be a second, brighter red derived from this one;
     the theme has one red, so the icon and its ring share it and the pulse keeps them apart. */
  root.setProperty('--danger-lit', theme.danger);
  root.setProperty('--danger-rgb', channels(theme.danger));

  /* The passing states: the core itself takes the colour, ring and icon -- nothing is added to it. */
  root.setProperty('--poison', theme.poison);
  root.setProperty('--poison-rgb', channels(theme.poison));
  root.setProperty('--boost-health', theme.boostHealth);
  root.setProperty('--boost-health-rgb', channels(theme.boostHealth));
  root.setProperty('--boost-stamina', theme.boostStamina);
  root.setProperty('--boost-stamina-rgb', channels(theme.boostStamina));

  /* Speaking: the voice disc fills with the chosen colour and its waves take whichever of ink and
     paper reads on it -- so a dark talking colour still shows its waves. */
  const talkInk = readableInk(theme.talk);
  root.setProperty('--talk', theme.talk);
  root.setProperty('--talk-ink', talkInk);
  root.setProperty('--talk-ink-rgb', channels(talkInk));

  /* The wallet: the money colour and one per row, each set only once a player has chosen it.
     Removed rather than set to a default when none is chosen -- hud.css reads each through a chain
     of var() fallbacks (row > the Wallet element's colour > money > the row's stock tone), so an
     unset variable is what hands the row down to the next one. */
  setOrClear(root, '--money', theme.money);
  setOrClear(root, '--money-cash', theme.moneyCash);
  setOrClear(root, '--money-bank', theme.moneyBank);
  setOrClear(root, '--money-dirty', theme.moneyDirty);
  setOrClear(root, '--money-gold', theme.moneyGold);
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
 *   over rules that live in several places (heartbeat, warnPulse, wvPulse), and there is
 *   no variable that reaches all of them.
 * ════════════════════════════════════════════════════════════════════════════ */
export function applyShape(shape: ShapeCfg): void {
  if (typeof document === 'undefined') return;

  const root = document.documentElement.style;

  root.setProperty('--core-ring-w', String(shape.ring));
  root.setProperty('--core-disc-a', String(shape.disc));
  root.setProperty('--core-ic-size', `${shape.icon * 100}%`);

  document.documentElement.classList.toggle('no-motion', !shape.motion);
}

/* ════════════════════════════════════════════════════════════════════════════
 * w_hud · settings/palette.ts
 * The Wraith theme's ink and paper (w_lib/nui/theme tokens.css) and its one red -- the HUD's
 * stock look, and the quick picks on top of every colour chooser.
 *
 * ★ Red Dead's own HUD is white and black, and the stock HUD still is: its cores paper on ink,
 *   the warning paper a step down, the red for danger. These tones are what it ships in.
 *
 * ★ Since SETTINGS_VERSION 5 every colour is the player's own and is painted exactly as chosen
 *   (the owner wants full freedom): ColorField offers these tones first and a full chooser under
 *   them, and theme.ts paints what was picked. Nothing is clamped at the paint any more.
 *
 * ⚠️ `toTone` survives for one job: reading a save from before that version. Every colour such a
 *   save held was only ever *seen* as its nearest tone here (the old clamp), so types.ts reads it
 *   as that tone (FREE_WARN_SINCE, FREE_ALL_SINCE) -- otherwise an old build's yellow warning or
 *   a blue accent from a friend's share code would reappear the moment the clamp came off, and
 *   opening this build would change what anyone sees. What is picked from now on is never toned.
 * ════════════════════════════════════════════════════════════════════════════ */

import { hexToHsv, hexToRgb, normHex } from './color';

/** Lightest first. The quick picks on top of every chooser (and RED on the danger field). */
export const TONES = [
  '#FFFFFF', // paper-lit
  '#F2F2F2', // paper
  '#B4B4B4', // paper-dim
  '#7A7A7A', // paper-faint
  '#333333', // ink-5
  '#222222', // ink-4
  '#111111', // ink-2
  '#0A0A0A', // ink
] as const;

export const PAPER = '#F2F2F2';
export const PAPER_DIM = '#B4B4B4';
export const PAPER_FAINT = '#7A7A7A';
export const INK = '#0A0A0A';
/** The mark: danger only. */
export const RED = '#CB0101';

/** CIE L* (0..100) -- lightness as the eye reads it, so the nearest tone looks nearest. */
function lightness(hex: string): number {
  const { r, g, b } = hexToRgb(hex);
  const lin = (c: number) => {
    const v = c / 255;
    return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
  };
  const y = 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b);
  return y > 216 / 24389 ? 116 * Math.cbrt(y) - 16 : (24389 / 27) * y;
}

const TONE_L = TONES.map((t) => lightness(t));

/** A saved colour that means "red" -- read as the mark where red is allowed. */
function isReddish(hex: string): boolean {
  const { h, s, v } = hexToHsv(hex);
  return (h <= 25 || h >= 335) && s >= 0.35 && v >= 0.25;
}

/**
 * The palette colour a stored colour *was* drawn as before colours went free -- used only to read
 * saves from before SETTINGS_VERSION 5 (types.ts).
 *   red: true -- the danger field: anything reddish is the theme's red.
 * Everything else lands on the ink/paper tone of the nearest lightness.
 */
export function toTone(input: string, opts: { red?: boolean } = {}): string {
  const hex = normHex(input, PAPER);
  if (opts.red && (hex === RED || isReddish(hex))) return RED;

  const l = lightness(hex);
  let best = 0;
  for (let i = 1; i < TONES.length; i += 1) {
    if (Math.abs(TONE_L[i] - l) < Math.abs(TONE_L[best] - l)) best = i;
  }
  return TONES[best];
}

/** `steps` tones darker than `tone` (a palette tone), stopping at ink. */
export function darker(tone: string, steps: number): string {
  const i = TONES.indexOf(tone as (typeof TONES)[number]);
  if (i < 0) return tone;
  return TONES[Math.min(TONES.length - 1, i + steps)];
}

/** `steps` tones lighter than `tone`, stopping at paper-lit. */
export function lighter(tone: string, steps: number): string {
  const i = TONES.indexOf(tone as (typeof TONES)[number]);
  if (i < 0) return tone;
  return TONES[Math.max(0, i - steps)];
}

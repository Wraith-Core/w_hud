/* ════════════════════════════════════════════════════════════════════════════
 * w_hud · settings/palette.ts
 * The only colours the HUD may draw: the Wraith theme's ink and paper (w_lib/nui/theme
 * tokens.css), and its one red as a mark.
 *
 * ★ Red Dead's own HUD is white and black. Its cores are paper on ink, and the one colour
 *   it allows itself is the red that flashes when a core runs out -- so the danger state is
 *   the only thing here that may be red, and nothing else can be picked red.
 *
 * ⚠️ Saved colours are never rewritten. A player may hold a blue accent or a green circle
 *   from an older build (or a share code from a friend); what is stored stays stored, and
 *   is *drawn* as the nearest tone of this palette. `toTone` is called where a colour is
 *   painted (theme.ts, App.tsx, layout.tsx, ColorField.tsx), never where it is read.
 * ════════════════════════════════════════════════════════════════════════════ */

import { hexToHsv, hexToRgb, normHex } from './color';

/** Lightest first. The HUD's picker offers exactly these (and RED on the danger field). */
export const TONES = [
  '#F6F1E6', // paper-lit
  '#EDE6D6', // paper
  '#B9AF9C', // paper-dim
  '#7D7466', // paper-faint
  '#38322A', // ink-5
  '#27231C', // ink-4
  '#15130F', // ink-2
  '#0B0A08', // ink
] as const;

export const PAPER = '#EDE6D6';
export const PAPER_DIM = '#B9AF9C';
export const PAPER_FAINT = '#7D7466';
export const INK = '#0B0A08';
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
 * The palette colour a stored colour is drawn as.
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

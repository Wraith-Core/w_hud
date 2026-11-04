/* ════════════════════════════════════════════════════════════════════════════
 * w_hud · settings/frame.ts
 * What a widget's x means on a screen that is not 16:9.
 *
 *   x is a percentage of the 16:9 width of the screen's height (F = 177.78vh) -- on a 16:9
 *   screen exactly the percentage of the width it always was. Three zones keep each widget
 *   where it belongs when the screen is wider (21:9, 32:9) or narrower (16:10, 4:3):
 *
 *     x <= 36         from the LEFT edge:   left = x% of F        (the circles beside the minimap)
 *     x >= 64         from the RIGHT edge:  left = W - (100-x)% of F  (the wallet column)
 *     36 < x < 64     the middle, stretched evenly between the two  (the compass at 50 = centre)
 *
 *   ★ Continuous and monotone, so dragging never jumps; identical to the old "% of the width"
 *     on a 16:9 screen. Before this a layout saved on 16:9 drifted on 32:9 (a circle at 16.6%
 *     of 5120px sat 850px from the edge while the minimap stays at ~30vh), and the circles'
 *     vh default had to be converted against the aspect at load (types.ts homeX).
 *   ⚠️ Valid for any screen of 4:3 or wider (see ZONE).
 *   Saves written before SETTINGS_VERSION 6 held "% of the width"; types.ts readWidgets
 *   converts them once against the screen they are read on (fromWidthPct).
 * ════════════════════════════════════════════════════════════════════════════ */

/**
 * The edge zones' width, in x units. 36 keeps the whole default circle row (the last horse
 * core is at 35.35) in the left zone; the middle zone stays monotone while W > 0.72 F
 * (4:3 = 0.75 F; on 5:4 only the middle band, ~30px wide, runs backwards).
 */
const ZONE = 36;
/** vh per x unit: F = 177.78vh, so 1% of F = 1.7778vh. */
const VH_PER_X = 16 / 9;

const n = (v: number) => +v.toFixed(4);

const frameW = (h: number) => (h * 16) / 9;

/** x (frame %) -> px from the left of a w x h screen. */
export function xToPx(x: number, w = window.innerWidth, h = window.innerHeight): number {
  const f = frameW(h);
  if (x <= ZONE) return (x / 100) * f;
  if (x >= 100 - ZONE) return w - ((100 - x) / 100) * f;
  const lo = (ZONE / 100) * f;
  const hi = w - lo;
  return lo + ((x - ZONE) / (100 - 2 * ZONE)) * (hi - lo);
}

/** px from the left -> x (frame %). The inverse of xToPx. */
export function pxToX(px: number, w = window.innerWidth, h = window.innerHeight): number {
  const f = frameW(h);
  const lo = (ZONE / 100) * f;
  const hi = w - lo;
  if (px <= lo) return (px / f) * 100;
  if (px >= hi) return 100 - ((w - px) / f) * 100;
  return ZONE + ((px - lo) / (hi - lo)) * (100 - 2 * ZONE);
}

/** The CSS `left` for x: follows a resize with no re-render (vh/vw only). */
export function xToCss(x: number): string {
  if (x <= ZONE) return `${n(x * VH_PER_X)}vh`;
  if (x >= 100 - ZONE) return `calc(100vw - ${n((100 - x) * VH_PER_X)}vh)`;
  const lo = n(ZONE * VH_PER_X);
  return `calc(${lo}vh + ${n((x - ZONE) / (100 - 2 * ZONE))} * (100vw - ${n(2 * lo)}vh))`;
}

/** An x stored as "% of the width" (saves before v6) -> x on this screen, so nothing moves. */
export function fromWidthPct(x: number): number {
  const w = window.innerWidth || 1920;
  const h = window.innerHeight || 1080;
  return Math.round(pxToX((x / 100) * w, w, h) * 100) / 100;
}

/** A length of `x` units in vh (the editor grid's cell). */
export const xUnitsVh = (x: number): number => n(x * VH_PER_X);

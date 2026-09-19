/* ════════════════════════════════════════════════════════════════════════════
 * w_hud · settings/color.ts
 * Colour maths for the control panel -- no library, nothing but what we use.
 *
 * ★ Why derive rather than ask for six colours?
 *
 *   The HUD's palette is a ramp, not a list: --gold-1/2/3 are one colour at three
 *   brightnesses, and asking a player to pick three shades that agree is asking them
 *   to do the designer's job. So the panel asks for **one** accent and derives the
 *   ramp from it -- exactly the way the stock palette is one white at three levels.
 * ════════════════════════════════════════════════════════════════════════════ */

export interface RGB { r: number; g: number; b: number }
export interface HSV { h: number; s: number; v: number }

const clamp = (n: number, a: number, b: number) => (n < a ? a : n > b ? b : n)
const to255 = (n: number) => clamp(Math.round(n), 0, 255)
const hex2 = (n: number) => to255(n).toString(16).padStart(2, '0')

/** Accepts #rgb, #rrggbb, rgb() and bare hex; anything unreadable falls back. */
export function normHex(input: unknown, fallback = '#FFFFFF'): string {
  if (typeof input !== 'string') return fallback

  let s = input.trim()
  if (s === '') return fallback

  const rgbMatch = /^rgba?\(\s*([\d.]+)[\s,]+([\d.]+)[\s,]+([\d.]+)/i.exec(s)
  if (rgbMatch) {
    return rgbToHex({ r: Number(rgbMatch[1]), g: Number(rgbMatch[2]), b: Number(rgbMatch[3]) })
  }

  if (s[0] !== '#') s = '#' + s
  if (/^#[0-9a-f]{3}$/i.test(s)) {
    return ('#' + s[1] + s[1] + s[2] + s[2] + s[3] + s[3]).toUpperCase()
  }
  if (/^#[0-9a-f]{6}$/i.test(s)) return s.toUpperCase()

  return fallback
}

export function hexToRgb(hex: string): RGB {
  const s = normHex(hex)
  return {
    r: parseInt(s.slice(1, 3), 16),
    g: parseInt(s.slice(3, 5), 16),
    b: parseInt(s.slice(5, 7), 16),
  }
}

export function rgbToHex({ r, g, b }: RGB): string {
  return ('#' + hex2(r) + hex2(g) + hex2(b)).toUpperCase()
}

export function rgbToHsv({ r, g, b }: RGB): HSV {
  const rr = r / 255, gg = g / 255, bb = b / 255
  const max = Math.max(rr, gg, bb), min = Math.min(rr, gg, bb)
  const d = max - min

  let h = 0
  if (d !== 0) {
    if (max === rr) h = ((gg - bb) / d + (gg < bb ? 6 : 0))
    else if (max === gg) h = (bb - rr) / d + 2
    else h = (rr - gg) / d + 4
    h *= 60
  }

  return { h, s: max === 0 ? 0 : d / max, v: max }
}

export function hsvToRgb({ h, s, v }: HSV): RGB {
  const hh = ((h % 360) + 360) % 360 / 60
  const c = v * s
  const x = c * (1 - Math.abs((hh % 2) - 1))
  const m = v - c

  let r = 0, g = 0, b = 0
  if (hh < 1) { r = c; g = x }
  else if (hh < 2) { r = x; g = c }
  else if (hh < 3) { g = c; b = x }
  else if (hh < 4) { g = x; b = c }
  else if (hh < 5) { r = x; b = c }
  else { r = c; b = x }

  return { r: (r + m) * 255, g: (g + m) * 255, b: (b + m) * 255 }
}

export const hexToHsv = (hex: string): HSV => rgbToHsv(hexToRgb(hex))
export const hsvToHex = (hsv: HSV): string => rgbToHex(hsvToRgb(hsv))

/** amount > 0 lightens toward white, < 0 darkens toward black. -1 .. 1 */
export function shade(hex: string, amount: number): string {
  const { r, g, b } = hexToRgb(hex)
  const t = amount < 0 ? 0 : 255
  const p = Math.abs(clamp(amount, -1, 1))

  return rgbToHex({
    r: (t - r) * p + r,
    g: (t - g) * p + g,
    b: (t - b) * p + b,
  })
}

export function mix(a: string, b: string, t: number): string {
  const x = hexToRgb(a), y = hexToRgb(b)
  const p = clamp(t, 0, 1)

  return rgbToHex({
    r: x.r + (y.r - x.r) * p,
    g: x.g + (y.g - x.g) * p,
    b: x.b + (y.b - x.b) * p,
  })
}

export function rgba(hex: string, alpha: number): string {
  const { r, g, b } = hexToRgb(hex)
  return `rgba(${to255(r)}, ${to255(g)}, ${to255(b)}, ${clamp(alpha, 0, 1)})`
}

/** Relative luminance -- used to pick black or white ink over a swatch. */
export function luminance(hex: string): number {
  const { r, g, b } = hexToRgb(hex)
  const f = (c: number) => {
    const v = c / 255
    return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4)
  }
  return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b)
}

export const readableInk = (hex: string): string => (luminance(hex) > 0.45 ? '#0A0A0A' : '#FFFFFF')

/* ============================================================
 * Wheel geometry
 *
 * Angles are in degrees from the top of the screen, clockwise -- the same convention as
 * shared/wheel.lua, so nothing is translated between them and nothing flips left for right.
 *
 *   SVG starts its angle at the +x axis and turns anticlockwise, hence:
 *       x = sin(a)   ·   y = -cos(a)
 *   That one equation is the whole difference. Everything below uses it and never re-derives it.
 * ============================================================ */

export const TAU = Math.PI * 2

/** A point on a circle of radius r at angle a in degrees (0 = top). */
export function polar(a: number, r: number): [number, number] {
  const rad = (a * Math.PI) / 180
  return [Math.sin(rad) * r, -Math.cos(rad) * r]
}

/**
 * The path of an annular sector (a wedge with a hole in its middle).
 *
 * `gap` is a gap in degrees cut from both ends -- it is what makes the white dividing lines
 * in the game wheel. Without a gap the sectors touch and read as one disc.
 */
export function sectorPath(
  angle: number,
  sweep: number,
  inner: number,
  outer: number,
  gap = 1.6,
): string {
  const half = Math.max(0, sweep / 2 - gap)
  const a1 = angle - half
  const a2 = angle + half
  const large = half * 2 > 180 ? 1 : 0

  const [ox1, oy1] = polar(a1, outer)
  const [ox2, oy2] = polar(a2, outer)
  const [ix2, iy2] = polar(a2, inner)
  const [ix1, iy1] = polar(a1, inner)

  return [
    `M ${ox1} ${oy1}`,
    `A ${outer} ${outer} 0 ${large} 1 ${ox2} ${oy2}`,
    `L ${ix2} ${iy2}`,
    `A ${inner} ${inner} 0 ${large} 0 ${ix1} ${iy1}`,
    'Z',
  ].join(' ')
}

/** The angle of a vector from the wheel centre, normalised to [0,360). */
export function angleOf(dx: number, dy: number): number {
  const deg = (Math.atan2(dx, -dy) * 180) / Math.PI
  return (deg + 360) % 360
}

/** The shortest signed difference between two angles -- for testing 'is the angle inside the sector'. */
export function angleDelta(a: number, b: number): number {
  return ((a - b + 540) % 360) - 180
}

/**
 * Which sector this angle falls in.
 *
 * ★ We compare against the full half-width, not the trimmed one: the gap is visual decoration,
 *   and letting it into the arithmetic would create dead zones between sectors where the
 *   player selects nothing -- the worst possible flaw in a wheel.
 */
export function sectorAt<T extends { angle: number; sweep: number }>(
  sectors: T[],
  angle: number,
): number {
  for (let i = 0; i < sectors.length; i++) {
    if (Math.abs(angleDelta(angle, sectors[i].angle)) <= sectors[i].sweep / 2) return i
  }
  return -1
}

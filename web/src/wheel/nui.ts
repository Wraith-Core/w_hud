/* ============================================================
 * The NUI bridge + RDR menu sounds
 *
 * ★ We duplicate no file: the sounds are in w_crafting and the images in w_inventory, and
 *   nui:// reads from any resource that declares its files. The paths arrive from Lua in
 *   `assets`, so they are not written twice here and neither is forgotten when moved.
 * ============================================================ */

declare function GetParentResourceName(): string

const resource = (): string => {
  try {
    return typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'w_hud'
  } catch {
    return 'w_hud'
  }
}

/** Call into Lua. Fails silently outside the game (browser preview) rather than breaking the UI. */
export async function post<T = unknown>(name: string, data: unknown = {}): Promise<T | null> {
  try {
    const res = await fetch(`https://${resource()}/${name}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data),
    })
    return (await res.json()) as T
  } catch {
    return null
  }
}

/* -- sounds ------------------------------------------------------------- */

export type Sfx = 'open' | 'close' | 'hover' | 'select' | 'deny'

const FILE: Record<Sfx, string> = {
  open: 'menu_open.mp3',
  close: 'menu_close.mp3',
  hover: 'button.mp3',
  select: 'selected.mp3',
  deny: 'button.mp3',
}

const VOL: Record<Sfx, number> = { open: 0.5, close: 0.45, hover: 0.22, select: 0.45, deny: 0.3 }

let base = ''
const cache: Partial<Record<Sfx, HTMLAudioElement>> = {}

export function setSoundBase(url: string): void {
  if (!url || url === base) return
  base = url
  for (const key of Object.keys(cache) as Sfx[]) delete cache[key]
}

let lastHover = 0

export function play(name: Sfx): void {
  if (!base || typeof Audio === 'undefined') return

  // Sweeping quickly between sectors used to fire dozens of tones a second, overlapping into
  // noise. A short threshold is enough: the tone is still heard and the overlap goes.
  if (name === 'hover') {
    const now = typeof performance !== 'undefined' ? performance.now() : Date.now()
    if (now - lastHover < 60) return
    lastHover = now
  }

  try {
    let warm = cache[name]
    if (!warm) {
      warm = new Audio(base + FILE[name])
      warm.preload = 'auto'
      cache[name] = warm
    }
    const node = warm.cloneNode(true) as HTMLAudioElement
    node.volume = VOL[name]
    void node.play().catch(() => {})
  } catch {
    /* Sound is a luxury -- it never takes the wheel down */
  }
}

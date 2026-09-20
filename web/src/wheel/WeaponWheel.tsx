/* ============================================================
 * w_hud · the weapon wheel
 *
 * ═══ Why selection is by angle, not by hover zones ═══
 *
 * RDR2's wheel selects by direction: wherever the cursor lands outside the centre disc, the
 * sector lying in that direction is picked however far away it is. Had we made each sector a
 * hover zone, the player would have to stand on the slice itself -- making the wheel slow and
 * fussy in a way nobody who has played the game expects.
 *
 * And the white gaps between sectors are decoration and stay out of the arithmetic, or they
 * would become dead zones where nothing is selected.
 *
 * ═══ Who owns the truth ═══
 *
 * Nothing is computed here: ammo, condition and ammo types all arrive from w_inventory, and
 * every action goes back to it as a command. The UI draws and sends, nothing more.
 * ============================================================ */

import { Fragment, useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { angleOf, polar, sectorAt } from './geometry'
import { play, post, setSoundBase } from './nui'
import type { AmmoOption, WheelItem, WheelPayload, WheelSector, WheelWeapon } from './types'

/**
 * The two sidearms drawn together.
 *
 * ★ Two sources, not one: under class distribution each holster has its named sector, and
 *   under slot ordering there are no roles -- the sectors are slot1..slot8 and there is no
 *   'sidearmRight' to look for. So we search by name first, and failing that take the first
 *   two eligible sidearms in wheel order -- which is exactly what dualPair computes in Lua, so
 *   the icon never shows two sidearms other than the ones that will come out.
 */
function findDualPair(
  sectors: WheelSector[],
  pick: (sector?: WheelSector) => WheelWeapon | undefined,
): { right: WheelWeapon; left: WheelWeapon } | undefined {
  const named = (role: string) => pick(sectors.find((s) => s.role === role))
  const right = named('sidearmRight')
  const left = named('sidearmLeft')

  if (right && left && right.dualCapable && left.dualCapable && right.slot !== left.slot) {
    return { right, left }
  }

  const found: WheelWeapon[] = []

  for (const sector of sectors) {
    const weapon = pick(sector)
    if (weapon?.dualCapable && !found.some((f) => f.slot === weapon.slot)) found.push(weapon)
    if (found.length === 2) break
  }

  return found.length === 2 ? { right: found[0], left: found[1] } : undefined
}

/* Geometry in SVG units -- the real scale comes from CSS, so the wheel grows with the screen without arithmetic. */
/* ═══ The proportions measured in pixels from the reference image (1320x881) ═══
 *
 *   wheel centre        (445, 441)
 *   bubble ring         radius 260px
 *   bubble diameter     90px    -> 0.345 x the ring radius
 *   selected bubble     108px   -> a scale of 1.21
 *   centre disc         diameter 366px (radius 183) -> 0.705 x the ring
 *   full wheel diameter 609px   -> 69% of the screen height
 *
 * ★ And between the disc's edge (183) and the bubble's inner edge (260-45=215) there is a
 *   **32px gap** -- which is what gives the reference its breathing room. My ring was at 72 of
 *   100, so the bubbles touched the disc and everything looked crowded.
 *
 * Reduced to the surface radius (R_OUT = 100): the ring is 85, the bubble is 14.7% of the
 * surface width, and the disc is 60% of it.
 */
const R_OUT = 100
const R_IN = 40
const R_ICON = 85 // the bubble ring
/**
 * The dead zone = the whole centre disc.
 *
 * ★ It used to be half of it (0.5), so the band between its half and its edge changed the
 *   selection while the cursor looked to the eye to be **inside the disc** rather than on a
 *   weapon -- which is exactly 'the mouse is not on the weapon and it still selects'. And the
 *   disc is also where the ammo switcher and the clean button are drawn, so making all of it
 *   dead solves both at once: precise pointing on the ring, and a safe route to the centre buttons.
 */
const DEADZONE = 1.0 // × R_IN

/* -- drawn icons ------------------------------------------------------- */

/* -- drawn icons --
   ★ Open strokes rather than solid fills: RDR2's icons are engraved thin, and everything drawn
     earlier with fill came out as a white block from which nothing could be read. */

/**
 * A fist drawn anatomically rather than as a line icon: a solid palm with four raised knuckles,
 * a thumb folded over the index finger, and inner shading to give it volume.
 *
 * ★ And why a drawing rather than an image: there is no 'unarmed' image in w_inventory/web/images
 *   at all (I searched for fist/unarmed/hand and found none). So if you add one named
 *   weapon_unarmed.png the wheel uses it automatically and skips this drawing.
 */
const FistIcon = () => (
  <svg viewBox="0 0 64 64" className="ww-vector" aria-hidden="true">
    <defs>
      <linearGradient id="ww-fist" x1="0.2" y1="0" x2="0.8" y2="1">
        <stop offset="0%" stopColor="currentColor" stopOpacity="1" />
        <stop offset="100%" stopColor="currentColor" stopOpacity="0.72" />
      </linearGradient>
    </defs>

    {/* the palm mass */}
    <path
      fill="url(#ww-fist)"
      d="M15.6 31.4c0-2.9 1.6-5 4.4-5.8v-4.9a4.3 4.3 0 0 1 8.6 0v3.4a4.3 4.3 0 0 1 8.2.2v-2.4a4.3 4.3 0 0 1 8.6 0v6.1c2.8 1 4.3 3.2 4.3 6.2v6.3c0 8.3-6.4 14.6-14.9 14.6h-5.5c-6.1 0-10.3-2.4-13.3-7.3l-4-6.5a3.6 3.6 0 0 1 5.5-4.6l3 3z"
    />

    {/* the knuckle lines -- engraved into the mass */}
    <g stroke="rgba(0,0,0,0.42)" strokeWidth="1.7" strokeLinecap="round" fill="none">
      <path d="M21.6 36.4h23.4M21.9 43.2h23.1" />
      <path d="M28.7 26.2v9.4M36.9 25.6v10M45.1 28.2v7.4" />
    </g>

    {/* the folded thumb */}
    <path
      fill="url(#ww-fist)"
      d="M20 33.4c-3.4.8-5.3 3.1-5.3 6.2 0 3 1.9 5.2 5.3 6.1z"
    />
    <path d="M20 33.4c-3.4.8-5.3 3.1-5.3 6.2 0 3 1.9 5.2 5.3 6.1"
      stroke="rgba(0,0,0,0.42)" strokeWidth="1.7" fill="none" strokeLinecap="round" />

    {/* a lower edge that gives the palm thickness */}
    <path d="M20.4 50.6c3.4 2.6 7.2 3.9 11.6 3.9h5.3c4.4 0 8-1.4 10.6-3.9"
      stroke="rgba(0,0,0,0.3)" strokeWidth="1.6" fill="none" strokeLinecap="round" />
  </svg>
)

/* (The two-arrow icon was removed: the dual-wield slot shows the two real sidearm images
   facing each other -- see .ww-dual in wheel.css) */

const QuickIcon = () => (
  <svg viewBox="0 0 24 24" className="ww-quick-icon" aria-hidden="true">
    <g fill="none" stroke="currentColor" strokeWidth="2.1" strokeLinecap="round">
      <path d="M20 12a8 8 0 1 1-2.6-5.9" />
      <path d="M18.4 2.4v4.2h-4.2" />
    </g>
  </svg>
)

/* -- the two card symbols --
   ★ Drawn rather than text glyphs: the RDR Catalogue font contains no club or diamond, so the
     browser fell back to another font and drew an unintelligible white block beside the counter. */

const ClubIcon = () => (
  <svg viewBox="0 0 24 24" className="ww-suit-icon" aria-hidden="true">
    <path d="M12 2.6a4 4 0 0 0-3.2 6.4A4 4 0 1 0 8.4 16h1.1l-1.1 5.4h7.2L14.5 16h1.1a4 4 0 1 0-.4-7A4 4 0 0 0 12 2.6z" />
  </svg>
)

const DiamondIcon = () => (
  <svg viewBox="0 0 24 24" className="ww-suit-icon" aria-hidden="true">
    <path d="M12 1.8 20.4 12 12 22.2 3.6 12z" />
  </svg>
)

/* -- small building blocks --------------------------------------------- */

/** The card symbol beside the counter -- the same two as the HUD: a diamond for the left holster and a club for the right. */
function Suit({ kind }: { kind: 'club' | 'diamond' }) {
  return (
    <span className={`ww-suit ww-suit-${kind}`}>
      {kind === 'club' ? <ClubIcon /> : <DiamondIcon />}
    </span>
  )
}

/**
 * A stat bar.
 *
 * The same texture the game uses (weapon_stats_bar + its mask) -- so the worn edges are original
 * rather than imitated in CSS. Both paths are injected as CSS variables in main.tsx.
 */
/**
 * An item or weapon image.
 *
 * ═══ Why a list of folders rather than one folder ═══
 *
 * ★ The images are not in this resource but in the inventory's, and every inventory names its
 *   folder as it pleases (w_inventory/web/images · vorp_inventory/html/img/items ·
 *   rsg-inventory/html/images). And one path written into the config means a wheel with eight
 *   empty discs on every server not running that exact inventory.
 *
 *   So we walk the list: the image fails and we try the next, until one hits or the list runs
 *   out and we draw nothing. And this tolerates a wrong guess at a folder: it is skipped without trace.
 *
 * ★ And `name` may not be the item name: RSG carries the image filename in a separate field
 *   (image) because many items share one image. So the caller passes what it knows and we draw
 *   it as given.
 */
function ItemImage({
  base,
  name,
  className,
}: {
  base: string | string[]
  name?: string | null
  className?: string
}) {
  // ⚠️ Identity by content, not by reference: the payload arrives from Lua so the list is built
  //    as a **new** array on every update. Had we depended on it directly, the cursor would
  //    reset to zero on every re-render, so the failed folders would be retried from the start
  //    on every ammo update -- a flicker in the icons and endless failed requests.
  const key = Array.isArray(base) ? base.join('|') : base

  // eslint-disable-next-line react-hooks/exhaustive-deps
  const bases = useMemo(() => (Array.isArray(base) ? base : [base]).filter(Boolean), [key])
  const [step, setStep] = useState(0)

  // A new folder or a new name => start from the top of the list, or a previous image's failure
  // keeps blocking the one after it.
  useEffect(() => setStep(0), [name, key])

  if (!name || step >= bases.length) return null

  return (
    <img
      className={className}
      src={`${bases[step]}${name}.png`}
      alt=""
      aria-hidden="true"
      draggable={false}
      onError={() => setStep((s) => s + 1)}
    />
  )
}

/**
 * The fist -- RDR2's own image, not a vector drawing.
 *
 * ★ Three attempts in order, and the first that works wins:
 *     1) w_inventory/web/images/weapon_unarmed.png  <- the server's override
 *     2) w_lib/web/build/assets/images/wheel/weapon_unarmed.png  <- the game's own (it really is there)
 *     3) the vector drawing                         <- should both be missing
 */
function UnarmedArt({ base, fallback }: { base: string | string[]; fallback?: string }) {
  const [step, setStep] = useState(0)

  const bases = Array.isArray(base) ? base : [base]
  const src =
    step < bases.length ? `${bases[step]}weapon_unarmed.png`
    : step === bases.length ? fallback
    : undefined

  if (!src) return <FistIcon />

  return (
    <img
      className="ww-icon-img fist"
      src={src}
      alt=""
      aria-hidden="true"
      draggable={false}
      onError={() => setStep((s) => s + 1)}
    />
  )
}

/* -- the wheel ---------------------------------------------------------- */

/* ★ No horse tab. It was a third one, adding an unused step to the TAB cycle, and it only opens
   near a horse with a satchel -- so it looks broken most of the time.
   Its path in client/wheel.lua is intact, so bringing it back is one line here. */
const TAB_ORDER: Array<WheelPayload['tab']> = ['weapons', 'items']

/**
 * RDR2 UI textures as CSS variables -- the same set as w_crafting, and each variable's name is
 * its file's name (main.jsx there does the same with --tex-<name>).
 *
 * ★ Injected at open time rather than written into CSS: the path arrives from Lua (nui://...)
 *   because it belongs to the inventory's resource, and CSS does not know another resource's name.
 */
const TEXTURES = [
  'crafting_highlight_t', 'crafting_highlight_b', 'crafting_highlight_l',
  'crafting_highlight_r', 'crafting_highlight_tl', 'crafting_highlight_tr',
  'crafting_highlight_bl', 'crafting_highlight_br', 'crafting_outline',
  'divider_line', 'title_divider', 'vertical_divider_line',
  'list_item_h_line_narrow', 'menu_header_1a', 'menu_bar',
  'selection_box_bg_1a', 'selection_box_bg_1c', 'toast_bg', 'help_text_bg',
  'selection_arrow_left', 'selection_arrow_right',
  'counter_bg_1a', 'swatch_bg_1a', 'star', 'tick', 'cross', 'lock',
] as const

function injectTextures(assets?: { tex?: string; dualwield?: string }): void {
  if (typeof document === 'undefined' || !assets) return

  const style = document.documentElement.style

  if (assets.tex) {
    for (const name of TEXTURES) style.setProperty(`--ww-tex-${name}`, `url("${assets.tex}${name}.png")`)
  }

  // A single image outside the texture folder -- it arrives with its full path from Lua
  if (assets.dualwield) style.setProperty('--ww-tex-dualwield', `url("${assets.dualwield}")`)
}

/**
 * The game's eight-sided frame (crafting_highlight_*) around the nearest positioned ancestor.
 * An exact copy of w_crafting/components/Frame.tsx -- decoration with no events.
 */
const FRAME_PIECES = ['t', 'b', 'l', 'r', 'tl', 'tr', 'bl', 'br'] as const

function Frame({ color, opacity }: { color?: string; opacity?: number }) {
  const style = {
    ...(color ? { '--ww-fr-c': color } : null),
    ...(opacity !== undefined ? { '--ww-fr-o': opacity } : null),
  } as React.CSSProperties

  return (
    <span className="ww-frame" style={style} aria-hidden="true">
      {FRAME_PIECES.map((piece) => (
        <span key={piece} className={`ww-fr-${piece}`} />
      ))}
    </span>
  )
}

/**
 * The badge cluster's position -- **flush against the outward edge** of the bubble, in its sector's direction.
 *
 * ★ The difference from before: it used to anchor the cluster's **centre** (56% of the bubble's
 *   width ~ 1.12 of its radius), so half of it lay over the weapon image and half in the air.
 *   Now its **inner edge** is anchored: a point at 58% then a shift by the cluster's own size in
 *   the same direction -- so it stands outside the disc, flush against it.
 *
 *   The shift: 0% when the direction is fully positive (so its left edge sits on the point),
 *   -100% when negative, and -50% when there is no direction on that axis -- so one equation is
 *   correct for all eight with no special cases.
 *
 *   And 58 rather than 50: on the diagonals (45 · 135 · 225 · 315) the cluster's corner comes
 *   closer to the edge than the midpoint of its side, so 50 pushes its corner about 7px onto the disc.
 */
const BADGE_ANCHOR = 58

function badgeAnchor(angle: number): React.CSSProperties {
  const [ox, oy] = polar(angle, 1)

  return {
    left: `${50 + ox * BADGE_ANCHOR}%`,
    top: `${50 + oy * BADGE_ANCHOR}%`,
    transform: `translate(${-50 + ox * 50}%, ${-50 + oy * 50}%)`,
  }
}

export default function WeaponWheel() {
  const [data, setData] = useState<WheelPayload | null>(null)
  const [hover, setHover] = useState(-1)
  const [cursors, setCursors] = useState<Record<string, number>>({})
  /** The default weapons in order -- a slot number as text, or 'dual', or 'unarmed' */
  const [quick, setQuick] = useState<string[]>([])
  const [busy, setBusy] = useState(false)

  /* The refs keep the message handlers stable without re-registering every frame. */
  const hoverRef = useRef(-1)
  const dataRef = useRef<WheelPayload | null>(null)
  const cursorsRef = useRef<Record<string, number>>({})

  hoverRef.current = hover
  dataRef.current = data
  cursorsRef.current = cursors

  const sectors = data?.sectors ?? []
  const t = data?.text ?? {}
  const assets = data?.assets

  /** The weapon under a given sector's cursor. */
  const pick = useCallback((sector?: WheelSector): WheelWeapon | undefined => {
    if (!sector || !sector.options.length) return undefined
    const raw = cursorsRef.current[sector.role] ?? sector.cursor - 1
    return sector.options[Math.max(0, Math.min(sector.options.length - 1, raw))]
  }, [])

  /* -- confirming the selection (key release or click) ------------------ */

  const commit = useCallback(() => {
    const payload = dataRef.current
    const index = hoverRef.current
    if (!payload || payload.tab !== 'weapons' || index < 0) return

    const sector = payload.sectors[index]
    if (!sector) return

    if (sector.role === 'unarmed') {
      play('select')
      void post('wheel:unarmed')
      return
    }

    if (sector.role === 'dual') {
      const pair = findDualPair(payload.sectors, pick)

      // Two distinct sidearms eligible for dual wield -- otherwise the request is meaningless.
      if (!pair || !payload.caps?.dual) {
        play('deny')
        return
      }

      play('select')
      void post('wheel:dual', { right: pair.right.slot, left: pair.left.slot })
      return
      // (The instance shown in the icon is this same one -- findDualPair is shared between them)
    }

    const weapon = pick(sector)
    if (!weapon) {
      play('deny')
      return
    }

    play('select')
    void post('wheel:equip', { slot: weapon.slot })
  }, [pick])

  /* -- messages from Lua ------------------------------------------------ */

  useEffect(() => {
    const onMessage = (event: MessageEvent) => {
      const msg = (event.data || {}) as Partial<WheelPayload> & { action?: string }

      if (msg.action === 'wheel:open') {
        const payload = msg as WheelPayload
        setSoundBase(payload.assets?.sounds || '')
        injectTextures(payload.assets)

        // We keep the previous round's cursors as long as the same sector exists: the player
        // reopens the wheel and finds their weapon under the cursor, not the head of the list.
        setCursors((prev) => {
          const next: Record<string, number> = {}
          for (const sector of payload.sectors) {
            const kept = prev[sector.role]
            next[sector.role] =
              kept !== undefined && kept < sector.options.length ? kept : sector.cursor - 1
          }
          return next
        })

        if (!dataRef.current) play('open')
        setData(payload)
        // ★ We tolerate both shapes: Lua sends a list, and older builds sent a single string.
        //   A UI that collapses on an old payload makes upgrading needlessly hard.
        setQuick(
          Array.isArray(payload.quick)
            ? payload.quick
            : payload.quick
              ? [payload.quick]
              : [],
        )
        return
      }

      if (msg.action === 'wheel:close') {
        if (dataRef.current) play('close')
        setData(null)
        setHover(-1)
        setBusy(false)
        return
      }

      if (msg.action === 'wheel:commit') commit()
    }

    window.addEventListener('message', onMessage)
    return () => window.removeEventListener('message', onMessage)
  }, [commit])

  /* -- what is selected right now --------------------------------------- */

  const hovered = hover >= 0 ? sectors[hover] : undefined
  const selected = useMemo(
    () => (hovered && data?.tab === 'weapons' ? pick(hovered) : undefined),
    // cursors is in the dependencies deliberately: pick reads it from the ref, so without it the
    // centre panel would stay on the old weapon after the mouse wheel turned.
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [hovered, data?.tab, cursors, pick],
  )

  /** The weapon in the other hand -- shown in a panel below the centre, as in the reference. */
  const otherHand = useMemo(() => {
    if (data?.tab !== 'weapons') return undefined

    const held: WheelWeapon[] = []
    for (const sector of sectors) {
      for (const option of sector.options) {
        if (option.held && !held.some((h) => h.slot === option.slot)) held.push(option)
      }
    }

    if (held.length < 2) return undefined
    // What is selected now is not 'the other' -- we show its companion.
    return held.find((h) => h.slot !== selected?.slot)
  }, [sectors, selected, data?.tab])

  /** The two sidearms that will be used together -- for the icon and for executing the command. */
  const dualPair = useMemo(() => {
    if (data?.tab !== 'weapons' || !data.caps?.dual) return undefined

    return findDualPair(sectors, pick)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [sectors, cursors, data?.tab, data?.caps?.dual, pick])

  const dualReady = Boolean(dualPair)

  /* -- switching the ammo type ------------------------------------------ */

  const cycleAmmo = useCallback(
    (step: number) => {
      const options = selected?.ammoOptions
      if (!selected || !options?.length || busy) return

      const start = Math.max(
        0,
        options.findIndex((o) => o.item === selected.ammoItem),
      )

      // What the player does not own is shown dimmed and is not navigated to -- as in the game.
      for (let hop = 1; hop <= options.length; hop++) {
        const index = (start + step * hop + options.length * options.length) % options.length
        const candidate = options[index]

        if (candidate && candidate.count > 0 && candidate.item !== selected.ammoItem) {
          setBusy(true)
          play('select')
          void post('wheel:ammo', { slot: selected.slot, item: candidate.item }).finally(() =>
            setBusy(false),
          )
          return
        }
      }

      play('deny')
    },
    [selected, busy],
  )

  const cleanWeapon = useCallback(() => {
    if (!selected || busy) return
    setBusy(true)
    play('select')
    void post('wheel:clean', {
      slot: selected.slot,
      name: selected.name,
      serial: selected.serial ?? null,
    }).finally(() => setBusy(false))
  }, [selected, busy])

  /* -- the mouse -------------------------------------------------------- */

  const surfaceRef = useRef<HTMLDivElement | null>(null)

  const onMove = useCallback(
    (event: React.MouseEvent<HTMLDivElement>) => {
      const box = surfaceRef.current?.getBoundingClientRect()
      if (!box) return

      const dx = event.clientX - (box.left + box.width / 2)
      const dy = event.clientY - (box.top + box.height / 2)

      // The wheel's radius on screen = half the container's smallest dimension (the viewBox is square).
      const scale = Math.min(box.width, box.height) / 2 / R_OUT
      const distance = Math.hypot(dx, dy) / scale

      // ★ The selection is sticky: inside the centre disc we do not clear it, we keep what was there.
      //
      //   The centre used to reset the selection, and the ammo switcher and clean button are drawn
      //   in the centre -- so the moment the cursor moved towards them the hovered weapon vanished
      //   and took with it the very buttons it was heading for. A road that could not be travelled.
      //
      //   And this is RDR2's own behaviour: the wheel is never without a selection after the first move.
      if (distance < R_IN * DEADZONE) return

      const next = sectorAt(sectors, angleOf(dx, dy))

      if (next >= 0 && next !== hoverRef.current) {
        play('hover')
        setHover(next)
      }
    },
    [sectors],
  )

  /** Cycling the weapons inside one sector -- for the mouse wheel and the bubble's arrows alike. */
  const cycleOption = useCallback((sector: WheelSector, step: number) => {
    if (sector.options.length < 2) return

    setCursors((prev) => {
      const size = sector.options.length
      const current = prev[sector.role] ?? sector.cursor - 1
      return { ...prev, [sector.role]: (current + step + size) % size }
    })
    play('hover')
  }, [])

  const onWheelScroll = useCallback(
    (event: React.WheelEvent<HTMLDivElement>) => {
      const sector = hoverRef.current >= 0 ? sectors[hoverRef.current] : undefined
      if (sector) cycleOption(sector, event.deltaY > 0 ? 1 : -1)
    },
    [sectors, cycleOption],
  )

  const items = data?.items ?? []

  // ════════════════════════════════════════════════════════════════════
  // Left click -- holster, not equip
  //
  // ★ Releasing already equips (the weapon to the hand, at the ready), so if the left button did
  //   the same thing one of the two actions would be wasted. And holstering had no direct route:
  //   you closed the wheel then double-tapped. Now it has its own button.
  //
  // ★ And the wheel stays open afterwards (stowCloses = false): whoever puts one sidearm away
  //   usually puts the second away after it, and closing after every holster means a fresh
  //   opening per hand. The other buttons are unchanged: release equips, and ESC closes.
  // ════════════════════════════════════════════════════════════════════
  const onClick = useCallback(() => {
    const payload = dataRef.current
    if (!payload) return

    if (payload.tab !== 'weapons') {
      const item = hoverRef.current >= 0 ? payload.items[hoverRef.current] : undefined
      if (!item) return play('deny')
      play('select')
      void post('wheel:useItem', { slot: item.slot })
      return
    }

    // The old behaviour is preserved behind Wheel.LeftClick = 'equip'
    if (!payload.stows) {
      commit()
      void post('wheel:close')
      return
    }

    const sector = hoverRef.current >= 0 ? payload.sectors[hoverRef.current] : undefined
    if (!sector) return play('deny')

    // 'Fists' is a holster of both hands -- which is exactly what the button means here.
    if (sector.role === 'unarmed') {
      play('select')
      void post('wheel:unarmed')
      return
    }

    const weapon = pick(sector)
    if (!weapon) return play('deny')

    play('select')
    void post('wheel:stow', { slot: weapon.slot })

    if (payload.stowShut) void post('wheel:close')
  }, [commit, pick])

  /**
   * Right click = add the weapon to the defaults or take it out of them.
   *
   * ★ And the default is a list, not a single target: a going-out kit is a sidearm and a sidearm,
   *   or a sidearm and a rifle. The assignment used to be single, so the second cancelled the first.
   *
   * ★ And the weapon is lowered into its holster at assignment time (in Lua): 'default' means my
   *   going-out weapon -- so let it be on my belt where I can see it, not at the bottom of the bag.
   */
  const onContext = useCallback(
    (event: React.MouseEvent<HTMLDivElement>) => {
      event.preventDefault()

      const sector = hoverRef.current >= 0 ? sectors[hoverRef.current] : undefined
      if (!sector) return play('deny')

      // ★ 'Dual wield' and 'fists' are sectors with no inventory slot, and assigning them used to
      //   be refused because pick() finds no weapon behind them -- even though the most useful
      //   thing to assign quickly is drawing both sidearms. So they are sent in their own right.
      const payload: { slot?: number; role?: string } =
        sector.role === 'dual' || sector.role === 'unarmed'
          ? { role: sector.role }
          : (() => {
              const weapon = pick(sector)
              return weapon ? { slot: weapon.slot } : {}
            })()

      if (payload.slot === undefined && payload.role === undefined) return play('deny')

      play('select')
      void post<{ quick: string[] }>('wheel:quick', payload).then((res) => {
        if (res) setQuick(Array.isArray(res.quick) ? res.quick : [])
      })
    },
    [sectors, pick],
  )

  /* -- the keyboard ----------------------------------------------------- */

  // ★ No key is read here. The keys of the wheel are a w_lib prompt group shown by client/wheel.lua
  //   while the wheel is open: the library listens to them and Lua forwards the completed key as
  //   'wheel:key'. The UI only acts on it, because it owns the selection under the cursor.
  useEffect(() => {
    if (!data) return

    const onKey = (event: MessageEvent) => {
      const msg = (event.data || {}) as { action?: string; key?: string }
      if (msg.action !== 'wheel:key') return

      const key = String(msg.key || '').toUpperCase()

      if (key === 'R') {
        const next = TAB_ORDER[(TAB_ORDER.indexOf(data.tab) + 1) % TAB_ORDER.length]
        play('hover')
        void post('wheel:tab', { tab: next })
        return
      }

      if (key === 'SPACE' && data.ability) {
        play('select')
        void post('wheel:ability')
        return
      }

      // The two arrows = D-Pad left/right in the game: switching the ammo type.
      if (key === 'LEFT' || key === 'RIGHT') {
        if (!selected?.ammoOptions?.length) return
        cycleAmmo(key === 'RIGHT' ? 1 : -1)
      }
    }

    window.addEventListener('message', onKey)
    return () => window.removeEventListener('message', onKey)
  }, [data, selected, cycleAmmo])

  // ★ TAB is the wheel's open key, and it is also the browser's focus-traversal key. So while
  //   the wheel was open, every press moved the white outline between the tabs
  //   (WEAPONS -> ITEMS -> HORSE) -- which the player sees as 'the selection jumping by itself'.
  //   We suppress the default behaviour while the wheel is up; navigation here is by mouse.
  //   The arrows are swallowed too, or they scroll the page under the wheel.
  useEffect(() => {
    if (!data) return

    const swallow = (event: KeyboardEvent) => {
      const key = event.key.toLowerCase()
      if (key === 'tab' || key === 'arrowleft' || key === 'arrowright' || key === ' ') {
        event.preventDefault()
      }
    }

    window.addEventListener('keydown', swallow)
    return () => window.removeEventListener('keydown', swallow)
  }, [data])

  /* -- what the library's prompt group shows ---------------------------- */

  // The rows that follow the selection: ammo switching (the hovered weapon owns more than one
  // ammo type) and holstering (the weapons tab, with the left click set to stow). Lua draws them
  // through w.prompt; we only say when they apply, and only when that changes.
  const opened = Boolean(data)
  const promptAmmo = Boolean(
    data && data.tab === 'weapons' && (data.caps?.ammoSwitch ?? true) && (selected?.ammoOptions?.length ?? 0) > 1,
  )
  const promptStow = Boolean(data && data.tab === 'weapons' && data.stows && (data.caps?.stow ?? true))

  useEffect(() => {
    if (!opened) return
    void post('wheel:prompts', { ammo: promptAmmo, stow: promptStow })
  }, [opened, promptAmmo, promptStow])

  if (!data || !assets) return null

  /* -- rendering -------------------------------------------------------- */

  const isWeapons = data.tab === 'weapons'
  const itemSlots: Array<WheelItem | undefined> = isWeapons
    ? []
    : Array.from({ length: sectors.length }, (_, i) => items[i])

  // ★ What the active inventory does not support is not drawn: VORP stores neither weapon
  //   condition nor per-instance ammo type, so there is no condition bar there, no ammo switcher
  //   and no clean button. Buttons that do nothing are worse than buttons that are absent.
  const caps = data.caps ?? { condition: true, clean: true, ammoSwitch: true, dual: true, stow: true }

  const ammoOptions: AmmoOption[] = (caps.ammoSwitch && selected?.ammoOptions) || []
  const activeAmmo = ammoOptions.find((o) => o.item === selected?.ammoItem)

  const conditionShown = Boolean(caps.condition && selected?.isGun)
  const needsClean = Boolean(caps.clean && selected?.isGun && selected.condition < 100)
  const oilReady = Boolean(data.oil?.enabled && data.oil.count >= data.oil.required)

  const tabs: Array<{ id: WheelPayload['tab']; label: string }> = [
    { id: 'weapons', label: t.weapons },
    { id: 'items', label: t.items },
  ]

  return (
    <div className={`ww-root wst-root${data.rtl ? ' rtl' : ''}`} dir={data.rtl ? 'rtl' : 'ltr'}>
      <div className="ww-vignette" />

      {/* The tab header -- R cycles them as in the game (the key is in the library's prompt group) */}
      <div className="ww-header">
        <div className="ww-header-plate">
          <Frame color="var(--ww-line-strong)" opacity={0.55} />
          {tabs.map((tab, i) => (
            <Fragment key={tab.id}>
              {i > 0 && <span className="ww-tab-sep" aria-hidden />}
              <button
                type="button"
                className={`ww-tab${data.tab === tab.id ? ' active' : ''}`}
                onClick={(event) => {
                  event.stopPropagation()
                  play('hover')
                  void post('wheel:tab', { tab: tab.id })
                }}
              >
                {tab.label}
              </button>
            </Fragment>
          ))}
        </div>
      </div>

      <div
        className="ww-surface"
        ref={surfaceRef}
        onMouseMove={onMove}
        onWheel={onWheelScroll}
        onClick={onClick}
        onContextMenu={onContext}
      >
        {/* The thin ring passing through the bubble centres */}
        <svg className="ww-svg" viewBox={`${-R_OUT} ${-R_OUT} ${R_OUT * 2} ${R_OUT * 2}`}>
          <circle cx="0" cy="0" r={R_ICON} className="ww-ring" />
        </svg>

        {/* ★ Circular bubbles rather than wedge sectors: every weapon in its own disc, and the
            selected one grows and is ringed in white. Hit testing stays angular so it works from any distance. */}
        <div className="ww-overlay">
          {sectors.map((sector, i) => {
            const [ix, iy] = polar(sector.angle, R_ICON)
            const style = {
              left: `${50 + (ix / R_OUT) * 50}%`,
              top: `${50 + (iy / R_OUT) * 50}%`,
            }

            const isSelected = hover === i
            const weapon = isWeapons ? pick(sector) : undefined
            const item = isWeapons ? undefined : itemSlots[i]

            // 'Dual wield' unavailable = an empty slot with an X like the other empties, not a
            // deleted bubble leaving a hole in the ring.
            const filled = isWeapons
              ? sector.role === 'dual'
                ? dualReady
                : Boolean(weapon) || sector.role === 'unarmed'
              : Boolean(item)

            // The weapon's position in the default list (0 = not in it). The number is shown when
            // the default is more than one: it says which comes out first.
            //
            // ★ For weapons we read weapon.quick as Lua computed it and match no text: the stored
            //   key is a slot in our inventory and a loadout identifier on VORP, and the UI does
            //   not know the difference and should not. For 'fists' and 'dual', their names are
            //   their keys, so those are matched as they are.
            const pinIndex = !isWeapons
              ? 0
              : sector.role === 'dual' || sector.role === 'unarmed'
                ? quick.indexOf(sector.role) + 1
                : (weapon?.quick ?? 0)

            const pinned = pinIndex > 0

            const classes = [
              'ww-bubble',
              isSelected ? 'selected' : '',
              filled ? '' : 'empty',
              weapon?.held ? 'equipped' : '',
              pinned ? 'pinned' : '',
              weapon?.stowed ? 'stowed' : '',
            ].filter(Boolean).join(' ')

            const many = isWeapons && sector.options.length > 1
            const cursor = (cursors[sector.role] ?? sector.cursor - 1) + 1

            return (
              <div className={classes} style={style} key={`${sector.role}-${i}`}>
                <span className="ww-bubble-face">
                  {!filled && <span className="ww-bubble-x" aria-hidden="true" />}

                  {isWeapons && sector.role === 'unarmed' && (
                    <UnarmedArt base={assets.items} fallback={assets.unarmed} />
                  )}
                  {/* ★ RDR2's own icon (weapon_dualwield), masked with the text colour -- so it
                      inverts to dark on the gold disc like every other icon. */}
                  {isWeapons && sector.role === 'dual' && dualPair && (
                    <span className="ww-dual" aria-hidden="true" />
                  )}

                  {isWeapons && weapon && (
                    <ItemImage base={assets.items} name={weapon.image || weapon.name} className="ww-icon-img" />
                  )}

                  {!isWeapons && item && (
                    <ItemImage base={assets.items} name={item.image || item.name} className="ww-icon-img" />
                  )}
                </span>

                {/* ★ All of the bubble's badges in **one cluster** on its outward side, and none
                    of them in a fixed corner.

                    The quick-select icon used to be in the top-right corner
                    (top/inset-inline-end) and the '1/2' counter in the top-left, while the cluster
                    is computed from the sector's angle -- so for the right-holster sector, whose
                    outward side is that very corner, the icon landed **on top of** the ammo counter
                    and the card symbol. And it cannot be fixed with an offset, because a fixed
                    corner coincides with the outward side in half the sectors.

                    So it all became one row ordered by flex: overlap is not merely avoided but
                    impossible, and the order is the same in all eight. */}
                {(weapon || item || pinned || many) && (
                  <span className="ww-badges" dir="ltr" style={badgeAnchor(sector.angle)}>
                    <span className="ww-badge-row">
                      {many && <span className="ww-more">{`${cursor}/${sector.options.length}`}</span>}

                      {isWeapons && weapon && (
                        <span className={`ww-ammo${weapon.loaded <= 0 ? ' empty' : ''}`}>
                          {weapon.loaded}
                        </span>
                      )}

                      {!isWeapons && item && <span className="ww-ammo">{item.count}</span>}

                      {isWeapons && weapon && sector.suit && (
                        <span className="ww-hand">
                          <Suit kind={sector.suit} />
                        </span>
                      )}

                      {pinned && (
                        <span className="ww-quick">
                          {quick.length > 1 ? <b>{pinIndex}</b> : <QuickIcon />}
                        </span>
                      )}
                    </span>

                    {weapon?.stowed && <span className="ww-stowed">{t.onHorse}</span>}
                  </span>
                )}

                {/* The in-sector navigation arrows -- shown on the selected bubble alone */}
                {isSelected && many && (
                  <>
                    <button
                      type="button"
                      className="ww-cycle prev"
                      aria-label="prev"
                      onClick={(event) => { event.stopPropagation(); cycleOption(sector, -1) }}
                    />
                    <button
                      type="button"
                      className="ww-cycle next"
                      aria-label="next"
                      onClick={(event) => { event.stopPropagation(); cycleOption(sector, 1) }}
                    />
                  </>
                )}
              </div>
            )
          })}
        </div>

        {/* The centre disc */}
        <div className="ww-center">
          <CenterPanel
            tab={data.tab}
            text={t}
            weapon={selected}
            item={!isWeapons && hover >= 0 ? itemSlots[hover] : undefined}
            role={hovered?.role}
            /* ★ Nothing hovered yet is not the same as an empty slot: the panel used to say
               'Empty' the moment the wheel opened, before the player had moved the mouse at all. */
            idle={hover < 0}
            dualReady={dualReady}
          />

          {isWeapons && selected && ammoOptions.length > 1 && (
            <div className="ww-ammo-switch">
              <button
                type="button"
                className="ww-arrow left"
                aria-label="prev"
                disabled={busy}
                onClick={(event) => { event.stopPropagation(); cycleAmmo(-1) }}
              />
              <span className="ww-ammo-label">{activeAmmo?.label || '—'}</span>
              <button
                type="button"
                className="ww-arrow right"
                aria-label="next"
                disabled={busy}
                onClick={(event) => { event.stopPropagation(); cycleAmmo(1) }}
              />
            </div>
          )}

          {isWeapons && selected && !selected.throwable && (
            <div className="ww-clip" dir="ltr">
              <ItemImage base={assets.items} name={selected.ammoItem} className="ww-clip-img" />
              <b className={selected.loaded <= 0 ? 'empty' : undefined}>{selected.loaded}</b>
              <span>{t.clip}</span>
            </div>
          )}

          {/* The weapon in the other hand -- a panel below the centre, as in the reference */}
          {isWeapons && otherHand && (
            <div className="ww-other">
              <span className="ww-other-hand">{otherHand.hand === 1 ? t.handLeft : t.handRight}</span>
              <span className="ww-other-name">{otherHand.label}</span>
              <ItemImage base={assets.items} name={otherHand.image || otherHand.name} className="ww-other-img" />
            </div>
          )}

          {isWeapons && needsClean && (
            <button
              type="button"
              className={`ww-clean${oilReady ? '' : ' disabled'}`}
              disabled={!oilReady || busy}
              onClick={(event) => { event.stopPropagation(); cleanWeapon() }}
            >
              <ItemImage base={assets.items} name={data.oil.name} className="ww-clean-img" />
              <span>{oilReady ? t.clean : t.noOil}</span>
              {oilReady && <span className="ww-clean-count">{data.oil.count}</span>}
            </button>
          )}
        </div>
      </div>

      {/* ═══ the stats panel -- a separate side panel ═══ */}
      <aside className="ww-panel">
        <div className="ww-panel-title">
          <Frame color="var(--ww-line-strong)" opacity={0.55} />
          <span>{t.statsTitle}</span>
        </div>

        {data.order.map((key) => {
          const isCondition = key === 'condition'
          const muted = isCondition ? !conditionShown : !selected && hovered?.role !== 'unarmed'
          const base = selected?.stats0 ?? (hovered?.role === 'unarmed'
            ? { damage: 20, range: 6, fireRate: 0, reload: 0, accuracy: 0 }
            : {})
          const value = muted ? 0 : (isCondition ? (selected?.condition ?? 0) : (base[key] ?? 0))

          return (
            <div className={`ww-row${muted ? ' muted' : ''}`} key={key}>
              <span className="ww-row-name">{t[key] || key}</span>
              {/* The handle is centred on the value -- the offset is in CSS via translate(-50%) */}
              <span className="ww-row-bar">
                <i style={{ width: `${Math.max(0, Math.min(100, value))}%` }} />
                <b style={{ insetInlineStart: `${Math.max(0, Math.min(100, value))}%` }} />
              </span>
              <span className="ww-row-val" dir="ltr">{isCondition ? `${Math.round(value)}%` : Math.round(value)}</span>
            </div>
          )
        })}

        <div className="ww-panel-hint">
          <span>{t.moveSelect}</span>
          {/* ★ 'Release to draw' rather than 'Release to confirm': releasing became a specific
              action -- the weapon to the hand -- once the left click took on another. */}
          <span>{t.draw}</span>
        </div>
      </aside>
    </div>
  )
}

/* -- the centre panel --------------------------------------------------- */

/** The weapon-class label above its name -- as the reference does ('Semi-Automatic Pistol'). */
const CATEGORY_KEY: Record<string, string> = {
  sidearm: 'catSidearm',
  longarm: 'catLongarm',
  melee: 'catMelee',
  throwable: 'catThrow',
  lasso: 'catLasso',
  kit: 'catKit',
}

function CenterPanel({
  tab,
  text,
  weapon,
  item,
  role,
  idle,
  dualReady,
}: {
  tab: WheelPayload['tab']
  text: Record<string, string>
  weapon?: WheelWeapon
  item?: WheelItem
  role?: string
  idle?: boolean
  dualReady?: boolean
}) {
  // Nothing hovered yet -- guidance, not the word 'Empty'
  if (idle) {
    return <div className="ww-info idle">{text.moveSelect}</div>
  }

  if (tab !== 'weapons') {
    if (!item) return <div className="ww-info empty">{text.empty}</div>
    return (
      <div className="ww-info">
        <div className="ww-cat">{`× ${item.count}`}</div>
        <div className="ww-title">{item.label}</div>
        <div className="ww-rule" />
      </div>
    )
  }

  // The dual-wield sector: no text when it is available (the two arrows say it),
  // and 'Empty' when it is not -- like the other empty slots.
  if (role === 'dual') {
    return <div className="ww-info empty">{dualReady ? '' : text.empty}</div>
  }

  if (role === 'unarmed') {
    return (
      <div className="ww-info">
        <div className="ww-cat">{text.unarmedSub}</div>
        <div className="ww-title">{text.unarmed}</div>
        <div className="ww-rule" />
      </div>
    )
  }

  if (!weapon) return <div className="ww-info empty">{text.empty}</div>

  return (
    <div className="ww-info">
      <div className="ww-cat">{text[CATEGORY_KEY[weapon.class] || ''] || ''}</div>
      {/* RDR2 names reach as far as 'Revolver Schofield Smith & Wesson No. 3' */}
      <div className={`ww-title${weapon.label.length > 22 ? ' long' : ''}`}>{weapon.label}</div>
      <div className="ww-rule" />
      {/* ⚠️ The test is on the displayed number, not on the multiplier: a multiplier of 1.004
          passes `> 1.001` then rounds to '+0%' -- a line that says nothing. */}
      {Math.round((weapon.damageMultiplier - 1) * 100) >= 1 && (
        <div className="ww-mod">{`+${Math.round((weapon.damageMultiplier - 1) * 100)}%`}</div>
      )}
    </div>
  )
}

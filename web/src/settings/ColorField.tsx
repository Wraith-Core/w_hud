/* ════════════════════════════════════════════════════════════════════════════
 * w_hud · settings/ColorField.tsx
 * A colour picker with no dependency -- a swatch that opens the theme's tones as quick picks and
 * a full chooser under them, on every colour field of the panel.
 *
 * ★ Why not <input type="color">?
 *
 *   Because CEF opens the operating system's colour dialog for it -- a Windows window,
 *   outside the game, behind it in fullscreen. The player clicks the swatch and nothing
 *   appears to happen. So the picker is drawn here, in the page, in the HUD's own idiom.
 *
 * ★ Tones first, then everything.
 *
 *   The stock HUD is white and black, like Red Dead's own, so the theme's ink and paper tones
 *   sit on top as one-click picks (and its red on the danger field). Under them is everything
 *   else -- the owner wants full freedom in the colours, and the HUD paints exactly what is
 *   picked (theme.ts): a saturation square and a hue rail, a row of ready colours (the game's
 *   poison green and fortify gold among them), and a #hex field. The swatch shows the colour
 *   itself. The picker stays open while a colour is picked, so it can be nudged afterwards.
 *
 * ★ Two ways back, beside the #hex field: `inherit` for a field that may follow something else
 *   (an element that follows the theme, a wallet row that follows the wallet), and `reset` for a
 *   field with a stock colour of its own ("Default") -- so no pick is a one-way door.
 *
 * ⚠️ Hue is kept in a ref alongside the hex, not derived from it on every render: a grey
 *   has no hue (s = 0), so dragging the saturation square down to grey and back up again
 *   would throw the hue away and come back red. The rail owns the hue; the square owns
 *   saturation and value.
 * ════════════════════════════════════════════════════════════════════════════ */

import { useEffect, useLayoutEffect, useRef, useState, type PointerEvent as ReactPointerEvent } from 'react';
import { createPortal } from 'react-dom';
import { useI18n } from '../i18n';
import { hexToHsv, hsvToHex, normHex, readableInk } from './color';
import { PAPER, RED, TONES } from './palette';

/* Ready colours: ones that read over a dark, moving game -- a warning yellow and orange, a red,
   RDR's fortify gold (the boosters' stock) and a paler gold, RDR's poisoned green (the poison's
   stock), a blue, a violet. Nothing so dark that it disappears against the ground; the tones above
   them already cover the whites and greys. */
const READY = ['#E8C547', '#F2994A', '#E05555', '#D9B45A', '#E7CE8A', '#6FAE55', '#8EC8E8', '#B48CD9'];

/** #RRGGBB (the # optional) -- applied as it is typed; anything shorter waits for Enter. */
const FULL_HEX = /^#?[0-9a-f]{6}$/i;

interface Props {
  value: string;
  onChange: (hex: string) => void;
  /** Shown as a "follow the theme" choice when the widget has no colour of its own. */
  inherit?: { active: boolean; label: string; onPick: () => void };
  /** A field with a stock colour of its own: one click back to it. */
  reset?: { active: boolean; label: string; onPick: () => void };
  title?: string;
  /** The danger field: the theme's red is offered among the quick picks too. */
  red?: boolean;
  /** Told whenever the chooser opens or closes (the panel previews the state being coloured). */
  onOpenChange?: (open: boolean) => void;
}

export function ColorField({ value, onChange, inherit, reset, title, red = false, onOpenChange }: Props) {
  const { t } = useI18n();
  const [open, setOpen] = useState(false);
  /* ⚠️ The popover is placed in viewport coordinates, not relative to the swatch.
     The panel scrolls its body and clips its own overflow, so a popover positioned inside
     it is cut off by whichever edge it reaches first -- and the picker is exactly the thing
     that needs to be taller than the row it hangs from. Fixed coordinates measured off the
     swatch escape both, and the clamp keeps it on screen. */
  const [at, setAt] = useState({ left: 0, top: 0 });
  const box = useRef<HTMLDivElement>(null);
  const btn = useRef<HTMLButtonElement>(null);
  const pop = useRef<HTMLDivElement>(null);

  /* The swatch shows (and the HUD is painted in) the colour itself. */
  const exact = normHex(value, PAPER);
  const shown = exact;
  const shelf: string[] = red ? [RED, ...TONES] : [...TONES];

  const onOpenRef = useRef(onOpenChange);
  onOpenRef.current = onOpenChange;
  useEffect(() => { onOpenRef.current?.(open); }, [open]);
  /* Closing by unmounting (the pane changed) still says so. */
  useEffect(() => () => { onOpenRef.current?.(false); }, []);

  const hsv = hexToHsv(exact);
  /* A grey (the stock warning, the stock money) has no hue: the square opens on a warm gold
     rather than on red, which would read as the danger colour. */
  const hueRef = useRef(hsv.s > 0.02 && hsv.v > 0.02 ? hsv.h : 40);
  if (hsv.s > 0.02 && hsv.v > 0.02) hueRef.current = hsv.h;
  const hue = hueRef.current;

  const [text, setText] = useState(exact);
  useEffect(() => { setText(exact); }, [exact]);

  /* Clicking anywhere else puts the picker away -- including on another swatch, so two
     pickers are never open over one another. */
  useEffect(() => {
    if (!open) return;

    const onDown = (e: MouseEvent) => {
      const target = e.target as Node;
      /* ⚠️ Both refs, not just the swatch's: the popover is portalled out of this
         component's DOM (see below), so it is not inside `box` any more -- and checking
         `box` alone closed the picker on the first click *inside* it. */
      if (box.current?.contains(target)) return;
      if (pop.current?.contains(target)) return;
      setOpen(false);
    };
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') { e.stopPropagation(); setOpen(false); } };

    window.addEventListener('mousedown', onDown, true);
    window.addEventListener('keydown', onKey, true);

    return () => {
      window.removeEventListener('mousedown', onDown, true);
      window.removeEventListener('keydown', onKey, true);
    };
  }, [open]);

  /** One handler for both surfaces: a press reads immediately, then follows the pointer. */
  const track = (
    e: ReactPointerEvent<HTMLDivElement>,
    read: (fx: number, fy: number) => void,
  ) => {
    e.preventDefault();
    e.stopPropagation();

    const el = e.currentTarget;
    const rect = el.getBoundingClientRect();

    const send = (cx: number, cy: number) => {
      read(
        Math.min(1, Math.max(0, (cx - rect.left) / rect.width)),
        Math.min(1, Math.max(0, (cy - rect.top) / rect.height)),
      );
    };

    send(e.clientX, e.clientY);

    const move = (ev: PointerEvent) => send(ev.clientX, ev.clientY);
    const up = () => {
      window.removeEventListener('pointermove', move);
      window.removeEventListener('pointerup', up);
    };

    window.addEventListener('pointermove', move);
    window.addEventListener('pointerup', up);
  };

  /* The hue rail on a grey (or near-black) colour: a grey has no hue to move, so picking one
     lifts it to a colour you can actually see rather than a grey with a tint nobody notices. */
  const pickHue = (h: number) => {
    hueRef.current = h;
    const grey = hsv.s < 0.15;
    onChange(hsvToHex({ h, s: grey ? 0.8 : hsv.s, v: grey ? Math.max(hsv.v, 0.9) : Math.max(hsv.v, 0.3) }));
  };

  /* Enter always applies what is in the field (even the colour already shown, which is how a
     "none chosen" money field is given that colour on purpose); leaving the field applies it
     only if it was changed, so clicking through it never picks a colour by accident. */
  const commitText = (force: boolean) => {
    const hex = normHex(text, exact);
    setText(hex);
    if (force || hex !== exact) onChange(hex);
  };

  /* A chip keeps the picker open, so the colour can still be nudged on the square or the rail. */
  const pickChip = (hex: string) => {
    onChange(hex);
  };

  /* Measure the actual editor-scale popup, independently from the HUD's tiny rem. */
  const place = () => {
    const el = btn.current;
    if (!el) return;

    const r = el.getBoundingClientRect();
    const unit = Math.max(1, Math.min(2, window.innerHeight / 1080));
    const bounds = pop.current?.getBoundingClientRect();
    const w = bounds?.width ?? 288 * unit;
    const h = bounds?.height ?? 460 * unit;
    const gap = 16 * unit;

    /* Below the swatch when there is room for it, above when there is not, and never
       past either side -- so a swatch near the bottom of the panel still opens fully. */
    let left = r.right - w;
    let top: number;
    if (r.bottom + gap + h <= window.innerHeight) top = r.bottom + gap;
    else if (r.top - gap - h >= gap) top = r.top - gap - h;
    else {
      /* ⚠️ A short screen (1280x720): the chooser is taller than the room above or below, and
         clamped there it lay over the very swatch (and field name) being coloured. Beside the
         swatch instead, centred on it -- on its left when there is room (in Arabic that is the
         panel's outer side, over the game), else on its right. */
      top = r.top + r.height / 2 - h / 2;
      if (r.left - gap - w >= gap) left = r.left - gap - w;
      else if (r.right + gap + w <= window.innerWidth - gap) left = r.right + gap;
    }

    setAt({
      left: Math.max(gap, Math.min(window.innerWidth - w - gap, left)),
      top: Math.max(gap, Math.min(window.innerHeight - h - gap, top)),
    });
  };

  useLayoutEffect(() => {
    if (!open) return;
    place();
    const observer = new ResizeObserver(place);
    if (pop.current) observer.observe(pop.current);
    window.addEventListener('resize', place);
    window.addEventListener('scroll', place, true);
    return () => {
      observer.disconnect();
      window.removeEventListener('resize', place);
      window.removeEventListener('scroll', place, true);
    };
  }, [open]);

  const toggle = () => {
    if (!open) place();
    setOpen((v) => !v);
  };

  return (
    <div className="hs-color" ref={box}>
      <button
        ref={btn}
        type="button"
        className={'hs-swatch' + (open ? ' is-open' : '')}
        style={{ background: shown, color: readableInk(shown) }}
        onClick={toggle}
        title={title}
      >
        {inherit?.active ? <span>{inherit.label}</span> : <span dir="ltr">{shown}</span>}
      </button>

      {/* ★ Portalled to <body>, not left where it was written.
          The panel's entrance animation ends on a transform, and `animation-fill-mode:
          both` leaves that transform in place for good -- which makes .hs-root the
          containing block for every fixed-position descendant and hands .hs-panel's
          `overflow: hidden` something to clip. So the popover was measured against the
          viewport and then positioned against the panel, and cut off by it besides.
          Out here it is a child of <body>: viewport coordinates mean the viewport, and
          nothing above it clips. */}
      {open && createPortal((
        <div
          ref={pop}
          className="hs-picker wst-root wst-panel is-free"
          style={{ left: `${at.left}px`, top: `${at.top}px` }}
          dir={document.documentElement.dir === 'rtl' ? 'rtl' : 'ltr'}
        >
          <span className="wst-frame" aria-hidden="true"><span className="wst-fr-t" /><span className="wst-fr-b" /><span className="wst-fr-l" /><span className="wst-fr-r" /><span className="wst-fr-tl" /><span className="wst-fr-tr" /><span className="wst-fr-bl" /><span className="wst-fr-br" /></span>

          <span className="hs-pick-cap">{t('settings.pickTones')}</span>
          <div className={'hs-shelf' + (red ? ' has-red' : '')}>
            {shelf.map((hex) => (
              <button
                key={hex}
                type="button"
                className={'hs-chip' + (hex === RED ? ' is-red' : '') + (hex === shown && !inherit?.active ? ' is-on' : '')}
                style={{ background: hex, color: readableInk(hex) }}
                onClick={() => pickChip(hex)}
                title={hex}
              />
            ))}
          </div>

          {/* ── the full chooser: square, rail, ready colours ── */}
          <span className="hs-pick-cap">{t('settings.pickAny')}</span>
          {/* ⚠️ Physical left/right on purpose, in both directions: the gradients run left to
              right and the pointer is read against the box's left edge, so under dir=rtl the
              square and the rail must not be mirrored or the dot would land opposite the colour. */}
          <div
            className="hs-sv"
            style={{ background: `linear-gradient(to top, #000, transparent), linear-gradient(to right, #fff, ${hsvToHex({ h: hue, s: 1, v: 1 })})` }}
            onPointerDown={(e) => track(e, (fx, fy) => onChange(hsvToHex({ h: hue, s: fx, v: 1 - fy })))}
          >
            <i
              className="hs-sv-dot"
              style={{ left: `${hsv.s * 100}%`, top: `${(1 - hsv.v) * 100}%`, borderColor: readableInk(exact) }}
            />
          </div>

          <div className="hs-hue" onPointerDown={(e) => track(e, (fx) => pickHue(fx * 360))}>
            <i className="hs-hue-dot" style={{ left: `${(hue / 360) * 100}%` }} />
          </div>

          <div className="hs-shelf is-ready">
            {READY.map((hex) => (
              <button
                key={hex}
                type="button"
                className={'hs-chip' + (hex === shown && !inherit?.active ? ' is-on' : '')}
                style={{ background: hex, color: readableInk(hex) }}
                onClick={() => pickChip(hex)}
                title={hex}
              />
            ))}
          </div>

          <div className="hs-hexrow">
            <input
              className="hs-hex"
              dir="ltr"
              value={text}
              spellCheck={false}
              maxLength={7}
              placeholder="#RRGGBB"
              aria-label={t('settings.pickHex')}
              title={t('settings.pickHex')}
              onChange={(e) => {
                const v = e.target.value;
                setText(v);
                if (FULL_HEX.test(v.trim())) onChange(normHex(v, exact));
              }}
              onBlur={() => commitText(false)}
              onKeyDown={(e) => { if (e.key === 'Enter') commitText(true); }}
            />
            {inherit && (
              <button
                type="button"
                className={'hs-mini' + (inherit.active ? ' is-on' : '')}
                onClick={() => { inherit.onPick(); setOpen(false); }}
              >
                {inherit.label}
              </button>
            )}
            {reset && (
              <button
                type="button"
                className={'hs-mini is-reset' + (reset.active ? ' is-on' : '')}
                onClick={() => { reset.onPick(); }}
              >
                {reset.label}
              </button>
            )}
          </div>
        </div>
      ), document.body)}
    </div>
  );
}
